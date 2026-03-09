import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @EnvironmentObject var depManager: DependencyManager
    @State private var preflightDismissed = false

    private var showPreflight: Bool {
        !preflightDismissed || (depManager.hasChecked && !depManager.allInstalled)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView()
                Divider()
                MainContentView()
            }
            .allowsHitTesting(!showPreflight)
            .blur(radius: showPreflight ? 4 : 0)

            if showPreflight {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                PreflightCheckView(dismissed: $preflightDismissed)
                    .environmentObject(depManager)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showPreflight)
    }
}

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @EnvironmentObject var depManager: DependencyManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mullvad Speed Test")
                        .font(.headline)
                    HStack(spacing: 6) {
                        if !vm.config.location.isEmpty {
                            Label(vm.config.location, systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !vm.userContinent.isEmpty {
                                Text("• \(vm.userContinent)")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            }
                        } else {
                            Text("WireGuard servers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if vm.viableTarget > 0 && vm.state.isRunning {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(vm.viableCount)/\(vm.viableTarget) viable")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(vm.viableCount >= vm.viableTarget ? .green : .orange)
                        }
                        if vm.isExpanding {
                            Text("→ expanding")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if vm.usePingFallback {
                            Label("Ping mode", systemImage: "wave.3.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .help("MTR unavailable — using ping fallback")
                        }
                    }
                }

                Spacer()

                statusBadge

                actionButton
            }
            .padding()

            // Dependency status bar
            if depManager.hasChecked {
                Divider()
                HStack(spacing: 8) {
                    if depManager.allInstalled {
                        Label("All dependencies installed", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Label("\(depManager.missingDependencies.count) missing dependencies", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        depManager.checkAll()
                    } label: {
                        Label("Recheck", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .background(.bar)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch vm.state {
        case .idle:
            Label("Ready", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if !vm.currentPhaseName.isEmpty {
                            Text(vm.currentPhaseName)
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                        Text(vm.currentServer.isEmpty ? progress : vm.currentServer)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if let start = vm.currentTestStartTime {
                            TimelineView(.periodic(from: start, by: 1)) { tl in
                                let secs = Int(max(0, tl.date.timeIntervalSince(start)))
                                Text("\(secs)s")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.orange.opacity(0.7))
                            }
                        }
                    }
                    // Metadata: continent + distance
                    HStack(spacing: 8) {
                        if !vm.currentServerContinent.isEmpty {
                            Label(vm.currentServerContinent, systemImage: "globe")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                        if vm.currentPhaseName == "Testing", let dist = vm.currentServerDistance {
                            Label(String(format: "%.0f km", dist), systemImage: "location")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    // 4-step pipeline
                    if !vm.currentTestSteps.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(vm.currentTestSteps, id: \.id) { step in
                                stepIcon(step)
                            }
                        }
                    }
                }
                .frame(maxWidth: 500)
            }
        case .completed(let count):
            Label("\(count) servers tested", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func stepIcon(_ step: TestStep) -> some View {
        HStack(spacing: 3) {
            Group {
                switch step.status {
                case .pending:
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary.opacity(0.4))
                case .active:
                    Image(systemName: step.icon)
                        .foregroundStyle(.orange)
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.system(size: 9))
            Text(step.label)
                .font(.caption2)
                .foregroundStyle(step.status == .pending ? Color.secondary.opacity(0.5) : Color.primary)
        }
    }

    private var actionButton: some View {
        Group {
            if vm.state.isRunning {
                Button(role: .destructive) {
                    vm.cancelTest()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    vm.startTest()
                } label: {
                    Label("Run Test", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Main Content

extension Notification.Name {
    static let openSettingsTab = Notification.Name("openSettingsTab")
    static let openAboutTab    = Notification.Name("openAboutTab")
}

struct MainContentView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @EnvironmentObject var depManager: DependencyManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ResultsTableView()
                .tabItem { Label("Results", systemImage: "tablecells") }
                .tag(0)

            LogAndStatsView()
                .tabItem { Label("Log", systemImage: "text.justify.left") }
                .tag(1)

            SettingsView()
                .environmentObject(vm)
                .environmentObject(depManager)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(2)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(3)
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAboutTab)) { _ in
            selectedTab = 3
        }
    }
}
