import SwiftUI

@main
struct VPNToolsApp: App {
    @StateObject private var speedTestVM = SpeedTestViewModel()
    @StateObject private var depManager = DependencyManager()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hidePreflightAtStartup") private var hidePreflightAtStartup = false
    @AppStorage("hasCompletedFirstPreflight") private var hasCompletedFirstPreflight = false

    var body: some Scene {
        // Menu bar icon — primary interface
        MenuBarExtra {
            MenuBarView(
                openDashboard: { openWindow(id: "dashboard") }
            )
                .environmentObject(speedTestVM)
                .environmentObject(depManager)
                .task {
                    depManager.checkAll()
                    // Always show on first launch; afterwards respect user preference
                    if !hasCompletedFirstPreflight || !hidePreflightAtStartup {
                        openWindow(id: "preflight")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        // Full dashboard window — golden ratio proportions (φ ≈ 1.618)
        Window("Zenith", id: "dashboard") {
            ContentView()
                .environmentObject(speedTestVM)
                .environmentObject(depManager)
                .frame(minWidth: 700, minHeight: 433)
        }
        .defaultSize(width: 900, height: 556)

        // Startup preflight window
        Window("System Check", id: "preflight") {
            StartupPreflightView()
                .environmentObject(depManager)
        }
        .defaultSize(width: 420, height: 500)
        .defaultPosition(.center)
    }

    private var menuBarIcon: String {
        switch speedTestVM.state {
        case .idle: return "star"
        case .running: return "star.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
