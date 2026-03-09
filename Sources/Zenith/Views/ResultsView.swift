import SwiftUI

struct ResultsTableView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @State private var sortOrder = [KeyPathComparator(\ServerResult.downloadSpeed, order: .reverse)]

    var body: some View {
        if vm.results.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                StatsCardsView()
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                Table(vm.sortedResults, sortOrder: $sortOrder) {
                TableColumn("Server", value: \.hostname) { result in
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text(result.hostname)
                                .font(.body.monospaced())
                            if !result.viable {
                                Text("non-viable")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.orange.opacity(0.12), in: Capsule())
                            }
                        }
                        Text("\(result.city), \(result.country)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 150, ideal: 200)

                TableColumn("Distance", value: \.distanceFormatted)
                    .width(min: 60, ideal: 80)

                TableColumn("Download") { result in
                    SpeedCell(value: result.downloadSpeed, label: result.downloadFormatted, color: .green)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Upload") { result in
                    SpeedCell(value: result.uploadSpeed, label: result.uploadFormatted, color: .blue)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Ping", value: \.pingFormatted)
                    .width(min: 50, ideal: 70)

                TableColumn("MTR") { result in
                    if result.mtrLatency > 0 {
                        HStack(spacing: 3) {
                            Text(String(format: "%.0f ms", result.mtrLatency))
                                .font(.body.monospacedDigit())
                            if result.mtrHops == 0 {
                                Text("ping")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15)))
                            }
                        }
                    } else {
                        Text("—").font(.body.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .width(min: 60, ideal: 85)
            }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No results yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Click \"Run Test\" to start testing Mullvad WireGuard servers")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Speed Cell

struct SpeedCell: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            SpeedBar(value: value, maxValue: 200, color: color)
                .frame(width: 40, height: 12)
            Text(label)
                .font(.body.monospacedDigit())
        }
    }
}

struct SpeedBar: View {
    let value: Double
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: min(geo.size.width, geo.size.width * value / maxValue))
            }
        }
    }
}

// MARK: - Stats View (kept as reusable cards)

struct StatsCardsView: View {
    @EnvironmentObject var vm: SpeedTestViewModel

    var body: some View {
        if !vm.results.isEmpty {
            HStack(spacing: 12) {
                StatCard(
                    title: "Best Download",
                    value: vm.bestServer?.downloadFormatted ?? "—",
                    subtitle: vm.bestServer?.hostname ?? "",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
                StatCard(
                    title: "Avg Download",
                    value: String(format: "%.1f Mbps", vm.averageDownload),
                    subtitle: "\(vm.results.count) servers",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                StatCard(
                    title: "Avg Ping",
                    value: String(format: "%.0f ms", vm.averagePing),
                    subtitle: "latency",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .orange
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Unified Log & Stats View

struct LogAndStatsView: View {
    @EnvironmentObject var vm: SpeedTestViewModel

    var body: some View {
        LogView()
    }
}

// MARK: - Log View

struct LogView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @State private var showRawLog = false

    private var visibleEntries: [LogEntry] {
        vm.logEntries.filter { $0.kind != .json }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                if !vm.userContinent.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption2)
                        Text(vm.userContinent)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.cyan)
                    if vm.isExpanding {
                        Text("→ expanding")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                if vm.viableTarget > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(vm.viableCount >= vm.viableTarget ? .green : .orange)
                            .frame(width: 6, height: 6)
                        Text("Viable: \(vm.viableCount)/\(vm.viableTarget)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(vm.viableCount >= vm.viableTarget ? .green : .orange)
                    }
                }
                Toggle(isOn: $showRawLog) {
                    Image(systemName: showRawLog ? "terminal.fill" : "list.bullet.rectangle")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help(showRawLog ? "Show rich log" : "Show raw log")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            if showRawLog {
                rawLogView
            } else {
                richLogView
            }
        }
    }

    private var richLogView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(visibleEntries) { entry in
                        logEntryView(entry)
                            .id(entry.id)
                    }
                }
                .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .onChange(of: vm.logEntries.count) { _, _ in
                if let last = visibleEntries.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .overlay {
            if vm.logEntries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Log output will appear here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private func logEntryView(_ entry: LogEntry) -> some View {
        switch entry.kind {
        case .header:
            if entry.text.isEmpty {
                Divider()
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Divider().padding(.vertical, 2)
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.cyan)
                            .frame(width: 3, height: 14)
                        Text(entry.text)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
        case .success:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 10))
                Text(entry.text)
                    .foregroundStyle(.green.opacity(0.9))
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.vertical, 1)
        case .warning:
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 10))
                Text(entry.text)
                    .foregroundStyle(.orange)
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.vertical, 1)
        case .error:
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 10))
                Text(entry.text)
                    .foregroundStyle(.red)
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.vertical, 1)
        case .result:
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 10))
                Text(entry.text)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 1)
        case .server:
            HStack(spacing: 5) {
                Image(systemName: "server.rack")
                    .foregroundStyle(.cyan.opacity(0.7))
                    .font(.system(size: 9))
                Text(entry.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.9))
            }
            .padding(.vertical, 1)
        case .info:
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue.opacity(0.6))
                    .font(.system(size: 9))
                Text(entry.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .padding(.vertical, 1)
        case .json:
            EmptyView()
        }
    }

    private var rawLogView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(vm.outputLog.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(line.hasPrefix("[stderr]") ? .red : .primary)
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
                .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: vm.outputLog.count) { _, _ in
                if let last = vm.outputLog.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
        .overlay {
            if vm.outputLog.isEmpty {
                Text("Log output will appear here")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
