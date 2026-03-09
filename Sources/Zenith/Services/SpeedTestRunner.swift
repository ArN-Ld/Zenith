import Foundation

/// Service that runs the Python speed test CLI and parses output
final class SpeedTestRunner {
    private var process: Process?
    private var outputBuffer = ""

    /// Standard PATH additions for macOS tools (Homebrew, system bins, Mullvad, pip user bins)
    static let toolPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/usr/sbin",
            "/Applications/Mullvad VPN.app/Contents/Resources",
            home + "/Library/Python/3.9/bin",
            home + "/Library/Python/3.10/bin",
            home + "/Library/Python/3.11/bin",
            home + "/Library/Python/3.12/bin",
            home + "/Library/Python/3.13/bin",
            home + "/.local/bin"
        ]
    }()

    /// Full PATH string combining system PATH with known tool locations
    static var enrichedPath: String {
        let systemPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        let extra = toolPaths.filter { !systemPath.contains($0) }
        return (extra + [systemPath]).joined(separator: ":")
    }

    /// Bundled Python source inside .app/Contents/Resources/python/
    private var bundledPythonPath: String? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let path = resourcePath + "/python"
        return FileManager.default.fileExists(atPath: path + "/vpn_tools/__init__.py") ? path : nil
    }

    /// Runtime directory for logs, DB, cache — writable location
    private var runtimeDir: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VPN Tools/runtime").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Run the speed test with the given configuration
    func run(
        config: SpeedTestConfig,
        onOutput: @escaping (String) -> Void,
        onResult: @escaping (ServerResult) -> Void,
        onStatus: @escaping (StatusEvent) -> Void,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) {
        let process = Process()
        self.process = process

        let pythonPath = findPython()

        // Determine source: bundled in .app or external fallback
        let pythonSourceDir: String
        let vendorDir: String?

        if let bundled = bundledPythonPath {
            pythonSourceDir = bundled
            let vendor = (Bundle.main.resourcePath ?? "") + "/python/vendor"
            vendorDir = FileManager.default.fileExists(atPath: vendor) ? vendor : nil
        } else if !config.vpnToolsPath.isEmpty {
            pythonSourceDir = config.vpnToolsPath + "/src"
            vendorDir = nil
        } else {
            let fallback = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/GitHub/vpn-tools/src"
            pythonSourceDir = fallback
            vendorDir = nil
        }

        process.executableURL = URL(fileURLWithPath: pythonPath)
        // Set CWD to runtime dir so relative paths work
        process.currentDirectoryURL = URL(fileURLWithPath: runtimeDir)

        var args = ["-m", "vpn_tools.mullvad_speed_test"]
        args += config.cliArguments
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        // Build PYTHONPATH: source dir + optional vendor dir
        var pypath = pythonSourceDir
        if let vendor = vendorDir {
            pypath += ":" + vendor
        }
        env["PYTHONPATH"] = pypath
        env["PYTHONUNBUFFERED"] = "1"
        env["VPN_TOOLS_RUNTIME_DIR"] = runtimeDir
        // Ensure all tools (mullvad, mtr, speedtest-cli) are discoverable
        env["PATH"] = Self.enrichedPath
        process.environment = env

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            self?.processOutput(str, onOutput: onOutput, onResult: onResult, onStatus: onStatus)
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                onOutput("[stderr] " + str)
            }
        }

        process.terminationHandler = { [weak self] proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            Task { @MainActor in
                if proc.terminationStatus == 0 {
                    onComplete(.success(()))
                } else {
                    onComplete(.failure(SpeedTestError.processExited(code: proc.terminationStatus)))
                }
            }

            // Ensure VPN is disconnected after test completes or fails
            self?.disconnectMullvad()
        }

        do {
            try process.run()
        } catch {
            onComplete(.failure(error))
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
        disconnectMullvad()
    }

    // MARK: - Mullvad Disconnect

    /// Disconnect Mullvad VPN to leave the system in a clean state
    private func disconnectMullvad() {
        let mullvadPath = Self.findExecutable("mullvad")
        guard !mullvadPath.isEmpty else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: mullvadPath)
        proc.arguments = ["disconnect"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    // MARK: - Output Parsing

    private func processOutput(
        _ text: String,
        onOutput: @escaping (String) -> Void,
        onResult: @escaping (ServerResult) -> Void,
        onStatus: @escaping (StatusEvent) -> Void
    ) {
        outputBuffer += text
        let lines = outputBuffer.components(separatedBy: "\n")

        // Keep incomplete last line in buffer
        outputBuffer = lines.last ?? ""

        for line in lines.dropLast() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Try to parse as JSON result line first
            if let result = parseJSONResultLine(trimmed) {
                Task { @MainActor in
                    onResult(result)
                    onOutput(trimmed)
                }
            } else if let status = parseJSONStatusLine(trimmed) {
                Task { @MainActor in
                    onStatus(status)
                    onOutput(trimmed)
                }
            } else {
                Task { @MainActor in
                    onOutput(trimmed)
                }
            }
        }
    }

    /// Parse a JSON line emitted by --machine-readable mode
    private func parseJSONResultLine(_ line: String) -> ServerResult? {
        guard line.hasPrefix("{"),
              let data = line.data(using: .utf8) else { return nil }

        struct JSONResult: Decodable {
            let type: String
            let hostname: String
            let country: String
            let city: String
            let distance_km: Double
            let connection_time: Double
            let download_speed: Double
            let upload_speed: Double
            let ping: Double
            let jitter: Double
            let packet_loss: Double
            let mtr_latency: Double
            let mtr_packet_loss: Double
            let mtr_hops: Int
            let viable: Bool
        }

        guard let json = try? JSONDecoder().decode(JSONResult.self, from: data),
              json.type == "result" else { return nil }

        return ServerResult(
            hostname: json.hostname,
            country: json.country,
            city: json.city,
            distance: json.distance_km,
            connectionTime: json.connection_time,
            downloadSpeed: json.download_speed,
            uploadSpeed: json.upload_speed,
            ping: json.ping,
            jitter: json.jitter,
            packetLoss: json.packet_loss,
            mtrLatency: json.mtr_latency,
            mtrPacketLoss: json.mtr_packet_loss,
            mtrHops: json.mtr_hops,
            viable: json.viable
        )
    }

    /// Parse a JSON status line
    private func parseJSONStatusLine(_ line: String) -> StatusEvent? {
        guard line.hasPrefix("{"),
              let data = line.data(using: .utf8) else { return nil }

        struct JSONStatus: Decodable {
            let type: String
            let phase: String
            let message: String
            let continent: String?
            let continents: [String]?
            let hostname: String?
            let city: String?
            let country: String?
            let distance_km: Double?
            let index: Int?
            let total: Int?
            let count: Int?
            let total_available: Int?
            let viable: Int?
            let target: Int?
            let tested: Int?
            let successful: Int?
            let exclude_continent: String?
        }

        guard let json = try? JSONDecoder().decode(JSONStatus.self, from: data),
              json.type == "status" else { return nil }

        return StatusEvent(
            phase: json.phase,
            message: json.message,
            continent: json.continent,
            continents: json.continents,
            hostname: json.hostname,
            city: json.city,
            country: json.country,
            distanceKm: json.distance_km,
            index: json.index,
            total: json.total,
            count: json.count,
            totalAvailable: json.total_available,
            viable: json.viable,
            target: json.target,
            tested: json.tested,
            successful: json.successful,
            excludeContinent: json.exclude_continent
        )
    }

    // MARK: - Helpers

    private func findPython() -> String {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/usr/bin/python3"
    }

    /// Find an executable by name across known paths
    static func findExecutable(_ name: String) -> String {
        for dir in toolPaths {
            let path = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return ""
    }
}

enum SpeedTestError: LocalizedError {
    case processExited(code: Int32)

    var errorDescription: String? {
        switch self {
        case .processExited(let code):
            return "Speed test process exited with code \(code)"
        }
    }
}
