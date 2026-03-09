import SwiftUI

/// Pre-flight dependency check overlay shown before allowing speed tests
struct PreflightCheckView: View {
    @EnvironmentObject var depManager: DependencyManager
    @Binding var dismissed: Bool
    @AppStorage("hidePreflightAtStartup") private var hideAtStartup = false
    @AppStorage("hasCompletedFirstPreflight") private var hasCompletedFirstPreflight = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(depManager.allInstalled ? .green : .blue)
                Text("System Check")
                    .font(.title2.bold())
                Text("Verifying required tools are available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Dependencies list
            VStack(spacing: 0) {
                ForEach(depManager.dependencies) { dep in
                    DependencyRow(dep: dep) {
                        Task { await depManager.install(dep) }
                    }
                    if dep.id != depManager.dependencies.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .padding(.vertical, 8)

            // Python detection
            Divider()
            HStack(spacing: 10) {
                Image(systemName: depManager.pythonPath.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(depManager.pythonPath.isEmpty ? .red : .green)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Python 3")
                        .font(.body.weight(.medium))
                    Text(depManager.pythonPath.isEmpty ? "Not found" : depManager.pythonPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Install log (if any)
            if !depManager.installLog.isEmpty {
                ScrollView {
                    Text(depManager.installLog)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 80)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                Divider()
            }

            // Actions
            VStack(spacing: 10) {
                if depManager.allInstalled {
                    Toggle(isOn: $hideAtStartup) {
                        Text("Don't show at next launch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .padding(.bottom, 2)

                    Button {
                        hasCompletedFirstPreflight = true
                        dismissed = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("All set — Continue")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .keyboardShortcut(.defaultAction)
                } else {
                    let autoInstallable = depManager.missingDependencies.filter {
                        if case .manual = $0.installMethod { return false }
                        return true
                    }
                    if !autoInstallable.isEmpty {
                        Button {
                            Task { await depManager.installAllMissing() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Install Missing")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(depManager.isInstalling)
                    }

                    Button {
                        depManager.checkAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Re-check")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(depManager.isInstalling)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .task {
            if !depManager.hasChecked {
                depManager.checkAll()
            }
        }
    }
}

// MARK: - Dependency Row

private struct DependencyRow: View {
    let dep: Dependency
    let installAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if dep.isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: dep.isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(dep.isInstalled ? .green : .red)
                        .font(.title3)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(dep.name)
                    .font(.body.weight(.medium))
                if dep.isInstalled {
                    Text(dep.foundPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(dep.installLabel)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if !dep.isInstalled && !dep.isInstalling {
                Button("Install") {
                    installAction()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
