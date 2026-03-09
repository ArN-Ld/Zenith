import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // MARK: - Icon + Identity
                VStack(spacing: 12) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: 88, height: 88)

                    VStack(spacing: 4) {
                        Text("Zenith")
                            .font(.title.bold())
                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.top, 12)

                // MARK: - Description
                Text("Find your peak VPN performance. Zenith ranks Mullvad servers by latency and download speed — right from the menu bar.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)

                Divider()

                // MARK: - Links
                VStack(alignment: .leading, spacing: 10) {
                    linkRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        label: "Zenith — source code",
                        url: "https://github.com/ArN-Ld/Zenith"
                    )
                    linkRow(
                        icon: "terminal",
                        label: "vpn-tools — Python CLI",
                        url: "https://github.com/ArN-Ld/vpn-tools"
                    )
                    linkRow(
                        icon: "lock.shield",
                        label: "Mullvad VPN",
                        url: "https://mullvad.net"
                    )
                }

                Divider()

                // MARK: - Dependencies
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built with")
                        .font(.caption.uppercaseSmallCaps())
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    depRow("Python 3.9+",     "subprocess runtime")
                    depRow("speedtest-cli",   "download speed measurement")
                    depRow("geopy",           "server geocoding")
                    depRow("mtr / ping",      "network latency")
                    depRow("Mullvad CLI",     "VPN relay list")
                    depRow("SwiftUI",         "native macOS interface")
                }

                Divider()

                // MARK: - License
                VStack(spacing: 6) {
                    Text("MIT License — © 2026 ArN-Ld")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Bundles vpn-tools — © 2025 Valera — MIT License")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button("View full license on GitHub") {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/ArN-Ld/Zenith/blob/main/LICENSE")!
                        )
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.bottom, 12)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private func linkRow(icon: String, label: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(Color.accentColor)
                Text(label)
                    .font(.callout)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func depRow(_ name: String, _ description: String) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption.bold())
            Text("·")
                .foregroundStyle(.tertiary)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
