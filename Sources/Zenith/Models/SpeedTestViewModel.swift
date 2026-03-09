import Foundation
import Combine

/// Status of a single test step in the 4-step pipeline
enum StepStatus: Equatable, Hashable {
    case pending
    case active
    case done(String?)  // optional result value
}

/// One of the 4 fixed test steps (connecting → stabilizing → speed test → MTR)
struct TestStep: Identifiable, Hashable {
    let id: String   // stable identifier
    var icon: String
    var label: String
    var status: StepStatus = .pending

    static func == (lhs: TestStep, rhs: TestStep) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
    }
}

/// ViewModel bridging the Python CLI runner with SwiftUI views
@MainActor
final class SpeedTestViewModel: ObservableObject {
    @Published var config = SpeedTestConfig()
    @Published var state: TestState = .idle
    @Published var results: [ServerResult] = []
    @Published var outputLog: [String] = []
    @Published var logEntries: [LogEntry] = []
    @Published var currentServer: String = ""
    @Published var userContinent: String = ""
    @Published var currentServerContinent: String = ""
    @Published var currentServerDistance: Double? = nil
    @Published var currentTestSteps: [TestStep] = []
    @Published var availableContinents: [String] = []
    @Published var currentTestInfo: StatusEvent?
    @Published var viableCount: Int = 0
    @Published var viableTarget: Int = 0
    @Published var isExpanding: Bool = false
    @Published var currentPhaseName: String = ""
    @Published var currentTestStartTime: Date? = nil
    @Published var usePingFallback: Bool = false

    private let runner = SpeedTestRunner()
    private var stepResetTask: Task<Void, Never>?

    /// Build the default 4-step pipeline for a server test
    private static func makeTestSteps() -> [TestStep] {
        [
            TestStep(id: "connect", icon: "network", label: "Connecting"),
            TestStep(id: "stabilize", icon: "wifi", label: "Stabilizing"),
            TestStep(id: "speedtest", icon: "arrow.up.arrow.down", label: "Speed test"),
            TestStep(id: "mtr", icon: "antenna.radiowaves.left.and.right", label: "MTR"),
        ]
    }

    /// Build a 2-step pipeline for calibration (connect only, no speed/mtr)
    private static func makeCalibrationSteps() -> [TestStep] {
        [
            TestStep(id: "connect", icon: "network", label: "Connecting"),
            TestStep(id: "calibrate", icon: "tuningfork", label: "Calibrating"),
        ]
    }

    /// Update a step's status by id
    private func setStep(_ id: String, status: StepStatus) {
        if let idx = currentTestSteps.firstIndex(where: { $0.id == id }) {
            currentTestSteps[idx].status = status
        }
    }

    /// Mark all prior steps as done (no value) and set the given step as active
    private func activateStep(_ id: String) {
        let order = currentTestSteps.map(\.id)
        guard let targetIdx = order.firstIndex(of: id) else { return }
        for (i, stepId) in order.enumerated() {
            if i < targetIdx {
                if let idx = currentTestSteps.firstIndex(where: { $0.id == stepId }),
                   case .done = currentTestSteps[idx].status { continue }
                setStep(stepId, status: .done(nil))
            } else if i == targetIdx {
                setStep(stepId, status: .active)
            }
        }
    }

    var sortedResults: [ServerResult] {
        results.sorted { $0.downloadSpeed > $1.downloadSpeed }
    }

    var bestServer: ServerResult? {
        sortedResults.first
    }

    var averageDownload: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.downloadSpeed).reduce(0, +) / Double(results.count)
    }

    var averageUpload: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.uploadSpeed).reduce(0, +) / Double(results.count)
    }

    var averagePing: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.ping).reduce(0, +) / Double(results.count)
    }

    func startTest() {
        results = []
        outputLog = []
        logEntries = []
        currentServer = ""
        userContinent = ""
        currentServerContinent = ""
        currentServerDistance = nil
        currentTestSteps = []
        availableContinents = []
        currentTestInfo = nil
        viableCount = 0
        viableTarget = 0
        isExpanding = false
        usePingFallback = false
        currentPhaseName = "Starting"
        state = .running(progress: "Starting speed test…")

        runner.run(
            config: config,
            onOutput: { [weak self] line in
                self?.outputLog.append(line)
                if let count = self?.outputLog.count, count > 500 {
                    self?.outputLog.removeFirst(count - 500)
                }
                let entry = LogEntry.classify(line)
                if entry.kind != .json || entry.text.isEmpty {
                    // Don't discard json but only append non-empty visible entries
                }
                self?.logEntries.append(entry)
                if let count = self?.logEntries.count, count > 500 {
                    self?.logEntries.removeFirst(count - 500)
                }
                self?.updateProgress(line)
            },
            onResult: { [weak self] result in
                self?.results.append(result)
                self?.currentServer = result.hostname
                let count = self?.results.count ?? 0
                let total = self?.config.maxServers ?? 15
                self?.state = .running(progress: "\(result.hostname) — \(result.downloadFormatted) [\(count)/\(total)]")
                // Mark all steps done with final metrics
                self?.setStep("connect", status: .done(nil))
                self?.setStep("stabilize", status: .done(nil))
                self?.setStep("speedtest", status: .done("\(result.downloadFormatted) ↑\(result.uploadFormatted)"))
                self?.setStep("mtr", status: .done(result.pingFormatted))
            },
            onStatus: { [weak self] status in
                self?.handleStatus(status)
                if let entry = status.toLogEntry() as LogEntry? {
                    self?.logEntries.append(entry)
                }
            },
            onComplete: { [weak self] outcome in
                switch outcome {
                case .success:
                    let count = self?.results.count ?? 0
                    self?.state = .completed(serverCount: count)
                case .failure(let error):
                    self?.state = .error(message: error.localizedDescription)
                }
                self?.currentTestInfo = nil
                self?.currentPhaseName = ""
                self?.currentTestStartTime = nil
                self?.currentTestSteps = []
            }
        )
    }

    func cancelTest() {
        runner.cancel()
        state = .idle
        currentTestInfo = nil
        currentPhaseName = ""
        currentTestStartTime = nil
        currentTestSteps = []
    }

    func resetResults() {
        results = []
        outputLog = []
        logEntries = []
        state = .idle
        currentServer = ""
        currentTestInfo = nil
        currentPhaseName = ""
        viableCount = 0
        isExpanding = false
        currentTestSteps = []
    }

    private func handleStatus(_ status: StatusEvent) {
        currentTestInfo = status

        switch status.phase {
        case "calibration":
            currentPhaseName = "Calibration"
            userContinent = status.continent ?? ""
            availableContinents = status.continents ?? []
            state = .running(progress: "Calibrating connections")
        case "calibration_test":
            currentPhaseName = "Calibration"
            currentTestStartTime = Date()
            currentServer = status.hostname ?? ""
            currentServerContinent = status.continent ?? ""
            stepResetTask?.cancel()
            currentTestSteps = Self.makeCalibrationSteps()
            activateStep("connect")
            let loc = [status.city, status.country].compactMap { $0 }.joined(separator: ", ")
            state = .running(progress: "\(status.hostname ?? "") (\(loc))")
        case "selection":
            currentPhaseName = "Selection"
            currentTestSteps = []
            let count = status.count ?? 0
            state = .running(progress: "Selected \(count) servers from \(userContinent)")
        case "testing":
            currentPhaseName = "Testing"
            currentTestStartTime = Date()
            currentServer = status.hostname ?? ""
            currentServerContinent = status.continent ?? ""
            currentServerDistance = status.distanceKm
            // Defer step reset so the previous "all done" state is visible
            stepResetTask?.cancel()
            let newSteps = Self.makeTestSteps()
            stepResetTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                currentTestSteps = newSteps
                activateStep("connect")
            }
            let idx = status.index ?? 0
            let total = status.total ?? config.maxServers
            state = .running(progress: "\(status.hostname ?? "") [\(idx)/\(total)]")
        case "progress":
            viableCount = status.viable ?? viableCount
            viableTarget = status.target ?? viableTarget
            currentTestStartTime = nil
        case "connecting":
            // If deferred reset is pending, apply it now
            if let task = stepResetTask, !task.isCancelled {
                task.cancel()
                currentTestSteps = Self.makeTestSteps()
            }
            activateStep("connect")
            state = .running(progress: currentServer)
        case "stabilizing":
            activateStep("stabilize")
            state = .running(progress: currentServer)
        case "speedtest_running":
            currentPhaseName = "Testing"
            activateStep("speedtest")
            state = .running(progress: currentServer)
        case "mtr_running":
            currentPhaseName = "Testing"
            activateStep("mtr")
            state = .running(progress: currentServer)
        case "mtr_ping_fallback":
            currentPhaseName = "Testing"
            usePingFallback = true
            // Update MTR step label to reflect ping fallback
            if let idx = currentTestSteps.firstIndex(where: { $0.id == "mtr" }) {
                currentTestSteps[idx] = TestStep(id: "mtr", icon: "wave.3.right", label: "Ping")
            }
            activateStep("mtr")
            state = .running(progress: currentServer)
        case "mtr_failed":
            // Step stays in active state briefly then the result will reset it
            break
        case "extension":
            currentPhaseName = "Expansion"
            isExpanding = true
            let excl = status.excludeContinent ?? userContinent
            state = .running(progress: "Expanding beyond \(excl)…")
        default:
            break
        }
    }

    private func updateProgress(_ line: String) {
        // Only update from text if no JSON status is driving it
        let lower = line.lowercased()
        if lower.contains("running speed test") {
            state = .running(progress: "🔄 Speed test in progress…")
        } else if lower.hasPrefix("connecting to") || (lower.hasPrefix("→") && lower.contains("connecting")) {
            let server = line.replacingOccurrences(of: "→ ", with: "")
                            .replacingOccurrences(of: "Connecting to ", with: "")
                            .replacingOccurrences(of: "...", with: "")
                            .trimmingCharacters(in: .whitespaces)
            state = .running(progress: "→ Connecting: \(server)")
        } else if lower.contains("mtr test in progress") || lower.contains("ping test in progress") {
            state = .running(progress: "📡 MTR/Ping test in progress…")
        } else if lower.contains("mtr unavailable") {
            state = .running(progress: "📡 Ping fallback in progress…")
        } else if lower.contains("stabiliz") {
            state = .running(progress: "⏳ Stabilizing connection…")
        }
    }
}
