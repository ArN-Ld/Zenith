import Foundation

/// Result from a single server speed test
struct ServerResult: Identifiable, Codable {
    let id: UUID
    let hostname: String
    let country: String
    let city: String
    let distance: Double?
    let connectionTime: Double
    let downloadSpeed: Double
    let uploadSpeed: Double
    let ping: Double
    let jitter: Double
    let packetLoss: Double
    let mtrLatency: Double
    let mtrPacketLoss: Double
    let mtrHops: Int
    let viable: Bool
    let timestamp: Date

    init(hostname: String, country: String, city: String, distance: Double?,
         connectionTime: Double = 0, downloadSpeed: Double, uploadSpeed: Double,
         ping: Double, jitter: Double = 0, packetLoss: Double = 0,
         mtrLatency: Double = 0, mtrPacketLoss: Double = 0, mtrHops: Int = 0,
         viable: Bool = true) {
        self.id = UUID()
        self.hostname = hostname
        self.country = country
        self.city = city
        self.distance = distance
        self.connectionTime = connectionTime
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.ping = ping
        self.jitter = jitter
        self.packetLoss = packetLoss
        self.mtrLatency = mtrLatency
        self.mtrPacketLoss = mtrPacketLoss
        self.mtrHops = mtrHops
        self.viable = viable
        self.timestamp = Date()
    }

    var downloadFormatted: String {
        String(format: "%.1f Mbps", downloadSpeed)
    }

    var uploadFormatted: String {
        String(format: "%.1f Mbps", uploadSpeed)
    }

    var pingFormatted: String {
        String(format: "%.0f ms", ping)
    }

    var distanceFormatted: String {
        guard let d = distance else { return "—" }
        return String(format: "%.0f km", d)
    }

    var connectionTimeFormatted: String {
        String(format: "%.1fs", connectionTime)
    }
}

/// Speed test configuration matching CLI arguments
struct SpeedTestConfig {
    var location: String = ""
    var maxServers: Int = 15
    var maxDistance: Int? = nil
    var defaultLat: Double? = nil
    var defaultLon: Double? = nil
    var verbose: Bool = false
    var maxServersHardLimit: Int = 45
    var minDownloadSpeed: Double = 3.0
    var connectionTimeout: Double = 20.0
    var minViableServers: Int = 8
    var countdownSeconds: Int = 5

    /// Path to the vpn-tools project
    var vpnToolsPath: String = ""

    /// Build CLI arguments array
    var cliArguments: [String] {
        var args: [String] = ["--non-interactive", "--no-open-results", "--machine-readable"]

        if !location.isEmpty {
            args += ["--location", location]
        }
        args += ["--max-servers", "\(maxServers)"]

        if let maxDist = maxDistance {
            args += ["--max-distance", "\(maxDist)"]
        }
        if let lat = defaultLat {
            args += ["--default-lat", "\(lat)"]
        }
        if let lon = defaultLon {
            args += ["--default-lon", "\(lon)"]
        }
        if verbose {
            args += ["--verbose"]
        }
        args += ["--max-servers-hard-limit", "\(maxServersHardLimit)"]
        args += ["--min-download-speed", "\(minDownloadSpeed)"]
        args += ["--connection-timeout", "\(connectionTimeout)"]
        args += ["--min-viable-servers", "\(minViableServers)"]
        args += ["--countdown-seconds", "0"]

        return args
    }
}

/// Overall test run state
enum TestState: Equatable {
    case idle
    case running(progress: String)
    case completed(serverCount: Int)
    case error(message: String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

/// Status event from the Python process for phase tracking
struct StatusEvent {
    let phase: String
    let message: String
    let continent: String?
    let continents: [String]?
    let hostname: String?
    let city: String?
    let country: String?
    let distanceKm: Double?
    let index: Int?
    let total: Int?
    let count: Int?
    let totalAvailable: Int?
    let viable: Int?
    let target: Int?
    let tested: Int?
    let successful: Int?
    let excludeContinent: String?

    /// Convert this status event into a rich log entry
    func toLogEntry() -> LogEntry {
        switch phase {
        case "calibration":
            let conts = (continents ?? []).joined(separator: ", ")
            let text = "Calibrating connections — \(continent ?? "Unknown") • Available: \(conts)"
            return LogEntry(timestamp: Date(), kind: .header, text: text)
        case "calibration_test":
            let loc = [city, country].compactMap { $0 }.joined(separator: ", ")
            return LogEntry(timestamp: Date(), kind: .server, text: "⏱ Calibrating: \(hostname ?? "") (\(loc))")
        case "selection":
            let c = count ?? 0
            let avail = totalAvailable ?? 0
            return LogEntry(timestamp: Date(), kind: .success, text: "Selected \(c) servers from \(avail) available — \(continent ?? "")")
        case "testing":
            let idx = index ?? 0
            let tot = total ?? 0
            let dist = distanceKm.map { String(format: "%.0f km", $0) } ?? ""
            let loc = [city, country].compactMap { $0 }.joined(separator: ", ")
            return LogEntry(timestamp: Date(), kind: .server, text: "[\(idx)/\(tot)] \(hostname ?? "") — \(loc) \(dist)")
        case "progress":
            let t = tested ?? 0
            let v = viable ?? 0
            let tgt = target ?? 0
            let s = successful ?? 0
            let icon = v >= tgt ? "✓" : "⚠"
            return LogEntry(timestamp: Date(), kind: v >= tgt ? .success : .info,
                          text: "\(icon) Progress: \(t) tested, \(v)/\(tgt) viable, \(s) successful")
        case "extension":
            return LogEntry(timestamp: Date(), kind: .warning,
                          text: "Expanding search beyond \(excludeContinent ?? "current zone")…")
        case "speedtest_running":
            return LogEntry(timestamp: Date(), kind: .info,
                          text: "↓↑ Speed test in progress: \(hostname ?? "")")
        case "mtr_running":
            return LogEntry(timestamp: Date(), kind: .info,
                          text: "📡 MTR test in progress: \(hostname ?? "")")
        case "mtr_ping_fallback":
            return LogEntry(timestamp: Date(), kind: .warning,
                          text: "⚠ MTR unavailable — using ping for latency measurement")
        case "mtr_failed":
            return LogEntry(timestamp: Date(), kind: .warning,
                          text: "⚠ \(message)")
        case "connecting":
            return LogEntry(timestamp: Date(), kind: .info,
                          text: "→ Connecting: \(hostname ?? "")")
        case "stabilizing":
            return LogEntry(timestamp: Date(), kind: .info,
                          text: "⏳ Stabilizing: \(hostname ?? "")")
        default:
            return LogEntry(timestamp: Date(), kind: .info, text: message)
        }
    }
}

/// Styled log entry for the rich log view
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let text: String

    enum Kind {
        case header      // cyan — phase titles
        case info        // default — informational
        case success     // green — good outcomes
        case warning     // orange — warnings
        case error       // red — failures
        case result      // green bold — server result
        case server      // monospaced — server being tested
        case json        // hidden from visual log (raw JSON)
    }

    /// Classify a raw output line into a LogEntry kind
    static func classify(_ line: String) -> LogEntry {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Skip JSON lines in visual display
        if trimmed.hasPrefix("{") {
            return LogEntry(timestamp: Date(), kind: .json, text: trimmed)
        }
        // Stderr
        if trimmed.hasPrefix("[stderr]") {
            return LogEntry(timestamp: Date(), kind: .error, text: String(trimmed.dropFirst(9)))
        }
        // Headers (separator lines or ALL CAPS titles)
        if trimmed.hasPrefix("───") || trimmed.hasPrefix("===") || trimmed.hasPrefix("---") {
            return LogEntry(timestamp: Date(), kind: .header, text: "")
        }
        if trimmed == trimmed.uppercased() && trimmed.count > 3 && !trimmed.contains(":") && trimmed.allSatisfy({ $0.isLetter || $0.isWhitespace || $0 == "/" || $0 == "+" }) {
            return LogEntry(timestamp: Date(), kind: .header, text: trimmed)
        }
        // Success markers
        if lower.hasPrefix("✓") || lower.contains("goal achieved") || lower.contains("test successful") || lower.contains("connected to") {
            let clean = trimmed.replacingOccurrences(of: "✓ ", with: "")
            return LogEntry(timestamp: Date(), kind: .success, text: clean)
        }
        // Warnings
        if lower.hasPrefix("⚠") || lower.hasPrefix("warning") || lower.contains("only") && lower.contains("viable") {
            let clean = trimmed.replacingOccurrences(of: "⚠ ", with: "")
            return LogEntry(timestamp: Date(), kind: .warning, text: clean)
        }
        // Errors
        if lower.hasPrefix("✗") || lower.hasPrefix("error") || lower.contains("failed") {
            return LogEntry(timestamp: Date(), kind: .error, text: trimmed)
        }
        // Server test headers
        if lower.hasPrefix("test ") && lower.contains("/") {
            return LogEntry(timestamp: Date(), kind: .header, text: trimmed)
        }
        // Speed/result lines
        if lower.contains("mbps") || lower.contains("download") && lower.contains("upload") {
            return LogEntry(timestamp: Date(), kind: .result, text: trimmed)
        }
        // Info (default)
        let clean = trimmed.replacingOccurrences(of: "ℹ ", with: "")
        return LogEntry(timestamp: Date(), kind: .info, text: clean)
    }
}
