import Foundation
import AppKit

/// Represents a required external dependency
struct Dependency: Identifiable {
    let id: String
    let name: String
    let checkCommand: String
    let installMethod: InstallMethod
    var isInstalled: Bool = false
    var isInstalling: Bool = false
    var foundPath: String = ""

    enum InstallMethod {
        case pip(package: String)
        case brew(formula: String)
        case manual(url: URL)
    }

    var installLabel: String {
        switch installMethod {
        case .pip(let pkg): return "pip install \(pkg)"
        case .brew(let formula): return "brew install \(formula)"
        case .manual(let url): return url.host ?? "Download"
        }
    }
}

/// Checks and installs external dependencies required by the speed test
@MainActor
final class DependencyManager: ObservableObject {
    @Published var dependencies: [Dependency] = [
        Dependency(
            id: "speedtest-cli",
            name: "speedtest-cli",
            checkCommand: "speedtest-cli",
            installMethod: .pip(package: "speedtest-cli")
        ),
        Dependency(
            id: "mtr",
            name: "mtr",
            checkCommand: "mtr",
            installMethod: .brew(formula: "mtr")
        ),
        Dependency(
            id: "mullvad",
            name: "Mullvad VPN",
            checkCommand: "mullvad",
            installMethod: .manual(url: URL(string: "https://mullvad.net/download/macos")!)
        )
    ]

    @Published var installLog: String = ""
    @Published var hasChecked: Bool = false
    @Published var pythonPath: String = ""

    var allInstalled: Bool {
        dependencies.allSatisfy(\.isInstalled)
    }

    var missingDependencies: [Dependency] {
        dependencies.filter { !$0.isInstalled }
    }

    var isInstalling: Bool {
        dependencies.contains { $0.isInstalling }
    }

    /// Check all dependencies
    func checkAll() {
        pythonPath = findPython()
        for i in dependencies.indices {
            let (found, path) = findCommand(dependencies[i].checkCommand)
            dependencies[i].isInstalled = found
            dependencies[i].foundPath = path
        }
        hasChecked = true
    }

    /// Install a specific dependency
    func install(_ dep: Dependency) async {
        guard let idx = dependencies.firstIndex(where: { $0.id == dep.id }) else { return }
        dependencies[idx].isInstalling = true
        installLog = ""

        switch dep.installMethod {
        case .pip(let package):
            let pipPath = findPip()
            if pipPath.isEmpty {
                // Fallback: use python3 -m pip
                let python = findPython()
                if !python.isEmpty {
                    let success = await runInstall(python, args: ["-m", "pip", "install", "--user", package])
                    dependencies[idx].isInstalled = success
                } else {
                    installLog = "Python not found. Cannot install pip packages."
                }
            } else {
                let success = await runInstall(pipPath, args: ["install", "--user", package])
                dependencies[idx].isInstalled = success
            }
        case .brew(let formula):
            let brewPath = findBrew()
            if brewPath.isEmpty {
                installLog = "Homebrew not found. Install from https://brew.sh"
            } else {
                let success = await runInstall(brewPath, args: ["install", formula])
                dependencies[idx].isInstalled = success
            }
        case .manual(let url):
            NSWorkspace.shared.open(url)
            installLog = "Opening download page…"
        }

        dependencies[idx].isInstalling = false
        // Re-check after install attempt
        let (found, path) = findCommand(dep.checkCommand)
        dependencies[idx].isInstalled = found
        dependencies[idx].foundPath = path
    }

    /// Install all missing dependencies that can be auto-installed
    func installAllMissing() async {
        for dep in missingDependencies {
            await install(dep)
        }
    }

    // MARK: - Private

    private func findCommand(_ command: String) -> (Bool, String) {
        // Check all known paths for the command
        for dir in SpeedTestRunner.toolPaths {
            let path = dir + "/" + command
            if FileManager.default.isExecutableFile(atPath: path) {
                return (true, path)
            }
        }

        // Fallback: use `which` with enriched PATH
        let proc = Process()
        let outPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["which", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = SpeedTestRunner.enrichedPath
        proc.environment = env
        proc.standardOutput = outPipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return (true, path)
            }
        } catch {}
        return (false, "")
    }

    private func runInstall(_ executable: String, args: [String]) async -> Bool {
        guard !executable.isEmpty else { return false }

        return await withCheckedContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: executable)
            proc.arguments = args

            // Inject enriched PATH so installed tools are found during install
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = SpeedTestRunner.enrichedPath
            proc.environment = env

            let pipe = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = errPipe

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.installLog += str
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.installLog += str
                }
            }

            proc.terminationHandler = { p in
                pipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: p.terminationStatus == 0)
            }

            do {
                try proc.run()
            } catch {
                Task { @MainActor in
                    self.installLog += "Failed to run: \(error.localizedDescription)\n"
                }
                continuation.resume(returning: false)
            }
        }
    }

    private func findPip() -> String {
        for path in ["/opt/homebrew/bin/pip3", "/usr/local/bin/pip3", "/usr/bin/pip3"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return ""
    }

    private func findBrew() -> String {
        for path in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return ""
    }

    private func findPython() -> String {
        for path in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return ""
    }
}
