import SwiftUI

/// Standalone window shown automatically at app startup for dependency checks
struct StartupPreflightView: View {
    @EnvironmentObject var depManager: DependencyManager
    @Environment(\.dismiss) private var dismiss
    @State private var dismissed = false

    var body: some View {
        VStack {
            PreflightCheckView(dismissed: $dismissed)
                .environmentObject(depManager)
                .padding()
        }
        .frame(minWidth: 420, minHeight: 300)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
        .onChange(of: dismissed) { _, isDismissed in
            if isDismissed {
                dismiss()
            }
        }
    }
}
