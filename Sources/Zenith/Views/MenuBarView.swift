import SwiftUI
import CoreLocation

/// Popover view shown from the menu bar icon
struct MenuBarView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @EnvironmentObject var depManager: DependencyManager
    @EnvironmentObject var updateChecker: UpdateChecker
    let openDashboard: () -> Void

    @State private var resolvedLat: Double?
    @State private var resolvedLon: Double?
    @State private var resolvedCity: String = ""
    @State private var resolvedCountry: String = ""
    @State private var resolvedContinent: String = ""
    @State private var geocodeStatus: String = ""
    @State private var geocodeTask: Task<Void, Never>?
    @State private var skipNextGeocode = false
    @State private var suggestions: [ResolvedLocation] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.primary)
                Text("Zenith")
                    .font(.headline)
                Spacer()
                statusIndicator
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Quick config
            VStack(spacing: 6) {
                // Location: validated state or editable field
                if vm.config.defaultLat != nil && vm.config.defaultLon != nil && !vm.config.location.isEmpty {
                    // Validated — show as label with edit button
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(vm.config.location)
                            .font(.callout)
                            .lineLimit(1)
                        if !vm.userContinent.isEmpty {
                            Text("• \(vm.userContinent)")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                        Spacer()
                        Button {
                            vm.config.defaultLat = nil
                            vm.config.defaultLon = nil
                        } label: {
                            Image(systemName: "pencil.circle")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Edit location")
                        Text("\(vm.config.maxServers)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Stepper("", value: $vm.config.maxServers, in: 1...50)
                            .labelsHidden()
                            .controlSize(.mini)
                    }
                } else {
                    // Editable state
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Location", text: $vm.config.location,
                                  prompt: Text("e.g. Paris, France"))
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            .onChange(of: vm.config.location) { _, newValue in
                                if skipNextGeocode {
                                    skipNextGeocode = false
                                    return
                                }
                                geocodeCity(newValue)
                            }
                        Text("\(vm.config.maxServers)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Stepper("", value: $vm.config.maxServers, in: 1...50)
                            .labelsHidden()
                            .controlSize(.mini)
                    }

                    // Autocomplete suggestions
                    if !suggestions.isEmpty && resolvedLat == nil {
                        VStack(spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, loc in
                                Button {
                                    applySuggestion(loc)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 8))
                                        Text(loc.displayName)
                                            .font(.caption)
                                        if !loc.continent.isEmpty {
                                            Spacer()
                                            Text(loc.continent)
                                                .font(.system(size: 9))
                                                .foregroundStyle(.cyan)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if loc.displayName != suggestions.last?.displayName {
                                    Divider().padding(.horizontal, 6)
                                }
                            }
                        }
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
                    }

                    // Resolved location button
                    if let lat = resolvedLat, let lon = resolvedLon {
                        Button {
                            applyResolved(lat: lat, lon: lon)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 3) {
                                        Text(resolvedCity.isEmpty ? "Unknown" : resolvedCity)
                                            .font(.caption2.bold())
                                        if !resolvedCountry.isEmpty {
                                            Text("• \(resolvedCountry)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !resolvedContinent.isEmpty {
                                            Text("• \(resolvedContinent)")
                                                .font(.caption2)
                                                .foregroundStyle(.cyan)
                                        }
                                    }
                                    Text(String(format: "%.4f, %.4f", lat, lon))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    } else if !geocodeStatus.isEmpty && suggestions.isEmpty {
                        HStack(spacing: 4) {
                            if geocodeStatus == "Resolving\u{2026}" {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "location.slash")
                                    .foregroundStyle(.orange)
                                    .font(.caption2)
                            }
                            Text(geocodeStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Dependency alerts
            if !depManager.allInstalled {
                dependencySection
                Divider()
            }

            // Progress FIRST (current test), then results summary below
            if case .running(let progress) = vm.state {
                VStack(spacing: 4) {
                    // Phase badge + server hostname + timer
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
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
                        if !vm.currentServerContinent.isEmpty {
                            Text("\u{00B7} \(vm.currentServerContinent)")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                        }
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

                    // Metadata row: distance + expanding (continent moved inline)
                    HStack(spacing: 8) {
                        if let dist = vm.currentServerDistance, vm.currentPhaseName == "Testing" {
                            Label(String(format: "%.0f km", dist), systemImage: "location")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if vm.isExpanding {
                            Text("expanding")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                    }

                    // Step pipeline (horizontal row, like dashboard)
                    if !vm.currentTestSteps.isEmpty {
                        Divider()
                        HStack(spacing: 10) {
                            ForEach(vm.currentTestSteps, id: \.id) { step in
                                stepRow(step)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .id("progress-\(vm.results.count)-\(vm.currentServer)")
                Divider()
            }

            // Best result summary (below progress, or standalone when idle)
            if !vm.results.isEmpty {
                resultsSummary
                    .id("results-\(vm.results.count)")
                Divider()
            }

            // Actions
            VStack(spacing: 2) {
                if vm.state.isRunning {
                    MenuBarButton(title: "Stop Test", icon: "stop.fill", color: .red) {
                        vm.cancelTest()
                    }
                } else {
                    MenuBarButton(title: "Run Speed Test", icon: "play.fill",
                                  color: depManager.allInstalled ? .green : .gray) {
                        if depManager.allInstalled {
                            vm.startTest()
                        }
                    }
                    .disabled(!depManager.allInstalled)
                }

                MenuBarButton(title: "Open Dashboard", icon: "macwindow", color: .blue) {
                    openDashboard()
                }

                Divider()

                MenuBarButton(title: "Settings…", icon: "gear", color: .primary) {
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: .openSettingsTab, object: nil)
                    openDashboard()
                }

                MenuBarButton(title: "About Zenith…", icon: "info.circle", color: .primary) {
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: .openAboutTab, object: nil)
                    openDashboard()
                }
                if updateChecker.updateAvailable, let v = updateChecker.latestVersion {
                    MenuBarButton(title: "Update \(v) available", icon: "arrow.down.circle.fill", color: .green) {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/ArN-Ld/Zenith/releases/latest")!
                        )
                    }
                }
                MenuBarButton(title: "Quit", icon: "power", color: .secondary) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 356)
    }

    // MARK: - Components

    @ViewBuilder
    private func stepRow(_ step: TestStep) -> some View {
        HStack(spacing: 5) {
            stepStatusIcon(step)
            Text(step.label)
                .font(.caption2)
                .foregroundStyle(step.status == .pending ? Color.secondary.opacity(0.5) : Color.primary)
            if case .done(let val) = step.status, let v = val {
                Spacer()
                Text(v)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func stepStatusIcon(_ step: TestStep) -> some View {
        switch step.status {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.4))
        case .active:
            Image(systemName: step.icon)
                .font(.system(size: 9))
                .foregroundStyle(.orange)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch vm.state {
        case .idle:
            Circle()
                .fill(.gray)
                .frame(width: 8, height: 8)
        case .running:
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
        case .completed:
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        case .error:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        }
    }

    private var resultsSummary: some View {
        VStack(spacing: 6) {
            // Averages row ABOVE best server
            HStack {
                Text("\(vm.results.count) servers")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                HStack(spacing: 10) {
                    Label(String(format: "%.1f Mbps", vm.averageDownload), systemImage: "arrow.down")
                        .foregroundStyle(.green.opacity(0.7))
                    Label(String(format: "%.1f Mbps", vm.averageUpload), systemImage: "arrow.up")
                        .foregroundStyle(.blue.opacity(0.7))
                    Label(String(format: "%.0f ms", vm.averagePing), systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.orange.opacity(0.7))
                }
                .font(.caption2.monospacedDigit())
            }

            if let best = vm.bestServer {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(best.hostname)
                            .font(.caption.monospaced())
                        HStack(spacing: 4) {
                            Text("\(best.city), \(best.country)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if vm.viableTarget > 0 {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                Text("\(vm.viableCount)/\(vm.viableTarget) viable")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(vm.viableCount >= vm.viableTarget ? .green : .orange)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(best.downloadFormatted)
                            .font(.callout.bold().monospacedDigit())
                            .foregroundStyle(.green)
                        HStack(spacing: 3) {
                            Text(best.pingFormatted)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if best.mtrHops == 0 && best.mtrLatency > 0 {
                                Text("ping")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15)))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var dependencySection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Missing Dependencies")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    depManager.checkAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Recheck")
            }

            ForEach(depManager.dependencies) { dep in
                HStack(spacing: 6) {
                    Image(systemName: dep.isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(dep.isInstalled ? .green : .red)
                        .font(.caption)
                    Text(dep.name)
                        .font(.caption)
                    Spacer()
                    if dep.isInstalling {
                        ProgressView()
                            .controlSize(.mini)
                    } else if !dep.isInstalled {
                        Button(action: {
                            Task { await depManager.install(dep) }
                        }) {
                            Text("Install")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // "Open Dashboard" nudge — shows full preflight
            MenuBarButton(title: "Open Dashboard for details", icon: "macwindow", color: .blue) {
                openDashboard()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Geocoding

    private func geocodeCity(_ input: String) {
        geocodeTask?.cancel()
        suggestions = []
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            resolvedLat = nil
            resolvedLon = nil
            resolvedCity = ""
            resolvedCountry = ""
            resolvedContinent = ""
            geocodeStatus = ""
            return
        }

        // Try Mullvad coordinates database first (instant, reliable)
        if let found = LocationResolver.shared.resolve(trimmed) {
            resolvedLat = found.latitude
            resolvedLon = found.longitude
            resolvedCity = found.city
            resolvedCountry = found.country
            resolvedContinent = found.continent
            geocodeStatus = ""
            return
        }

        // Show autocomplete suggestions from Mullvad database
        let matches = LocationResolver.shared.search(trimmed)
        if !matches.isEmpty {
            suggestions = matches
            geocodeStatus = ""
            return
        }

        // Fallback to CLGeocoder with debounce
        geocodeStatus = "Resolving…"
        geocodeTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.geocodeAddressString(trimmed)
                guard !Task.isCancelled else { return }
                if let pm = placemarks.first, let loc = pm.location {
                    resolvedLat = loc.coordinate.latitude
                    resolvedLon = loc.coordinate.longitude
                    resolvedCity = pm.locality ?? pm.name ?? trimmed
                    resolvedCountry = pm.country ?? ""
                    resolvedContinent = LocationResolver.continentFromCode(pm.isoCountryCode)
                    geocodeStatus = ""
                } else {
                    geocodeStatus = "Location not found"
                }
            } catch {
                guard !Task.isCancelled else { return }
                geocodeStatus = "Location not found"
            }
        }
    }

    private func applySuggestion(_ loc: ResolvedLocation) {
        vm.config.defaultLat = loc.latitude
        vm.config.defaultLon = loc.longitude
        skipNextGeocode = true
        vm.config.location = loc.displayName
        suggestions = []
        resolvedLat = nil
        resolvedLon = nil
        resolvedCity = ""
        resolvedCountry = ""
        resolvedContinent = ""
        geocodeStatus = ""
    }

    private func applyResolved(lat: Double, lon: Double) {
        vm.config.defaultLat = lat
        vm.config.defaultLon = lon
        skipNextGeocode = true
        vm.config.location = resolvedCity.isEmpty ? vm.config.location : resolvedCity + (resolvedCountry.isEmpty ? "" : ", \(resolvedCountry)")
        resolvedLat = nil
        resolvedLon = nil
        resolvedCity = ""
        resolvedCountry = ""
        resolvedContinent = ""
    }
}

// MARK: - Menu Bar Button

struct MenuBarButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }
}
