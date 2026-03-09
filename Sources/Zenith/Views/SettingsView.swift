import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var vm: SpeedTestViewModel
    @State private var pythonPath = ""
    @State private var detectedPython = ""
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
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            testSettings
                .tabItem { Label("Test", systemImage: "speedometer") }

            pathSettings
                .tabItem { Label("Paths", systemImage: "folder") }
        }
        .onAppear {
            detectPython()
        }
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Section("Location") {
                TextField("Reference location", text: $vm.config.location,
                          prompt: Text("e.g. Paris, France"))
                    .onChange(of: vm.config.location) { _, newValue in
                        if skipNextGeocode {
                            skipNextGeocode = false
                            return
                        }
                        geocodeCity(newValue)
                    }

                // Autocomplete suggestions
                if !suggestions.isEmpty && resolvedLat == nil {
                    VStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { _, loc in
                            Button {
                                applySuggestion(loc)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin")
                                        .foregroundStyle(.secondary)
                                        .font(.caption2)
                                    Text(loc.displayName)
                                        .font(.callout)
                                    if !loc.continent.isEmpty {
                                        Spacer()
                                        Text(loc.continent)
                                            .font(.caption2)
                                            .foregroundStyle(.cyan)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if loc.displayName != suggestions.last?.displayName {
                                Divider().padding(.horizontal, 8)
                            }
                        }
                    }
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }

                // Resolved location — click to validate
                if let lat = resolvedLat, let lon = resolvedLon {
                    Button {
                        applyResolved(lat: lat, lon: lon)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(resolvedCity.isEmpty ? "Unknown" : resolvedCity)
                                        .font(.caption.bold())
                                    if !resolvedCountry.isEmpty {
                                        Text("•")
                                            .foregroundStyle(.tertiary)
                                        Text(resolvedCountry)
                                            .font(.caption)
                                    }
                                    if !resolvedContinent.isEmpty {
                                        Text("•")
                                            .foregroundStyle(.tertiary)
                                        Text(resolvedContinent)
                                            .font(.caption)
                                            .foregroundStyle(.cyan)
                                    }
                                }
                                Text(String(format: "%.4f, %.4f", lat, lon))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                        .padding(6)
                        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                } else if !geocodeStatus.isEmpty && suggestions.isEmpty {
                    HStack(spacing: 8) {
                        if geocodeStatus == "Resolving…" {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "location.slash")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                        Text(geocodeStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Validated coordinates (compact)
                if let lat = vm.config.defaultLat, let lon = vm.config.defaultLon {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text(String(format: "%.4f, %.4f", lat, lon))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        TextField("Default latitude", value: $vm.config.defaultLat, format: .number)
                        TextField("Default longitude", value: $vm.config.defaultLon, format: .number)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Verbose logging", isOn: $vm.config.verbose)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Test Parameters

    private var testSettings: some View {
        ScrollView {
            Form {
                Section("Server limits") {
                    stepperRow("Max servers", value: $vm.config.maxServers, range: 1...100)
                    stepperRow("Hard limit", value: $vm.config.maxServersHardLimit, range: 1...200)
                    stepperRow("Min viable", value: $vm.config.minViableServers, range: 1...50)
                }

                Section("Geographic zone") {
                    Toggle("Limit search radius", isOn: Binding(
                        get: { vm.config.maxDistance != nil },
                        set: { vm.config.maxDistance = $0 ? 5000 : nil }
                    ))

                    if vm.config.maxDistance != nil {
                        stepperRow("Max distance", value: Binding(
                            get: { vm.config.maxDistance ?? 5000 },
                            set: { vm.config.maxDistance = $0 }
                        ), range: 500...50000, step: 500, unit: "km")
                    }

                    Text("Nearby servers are tested first. If not enough are viable, the search automatically expands to other continents.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Thresholds") {
                    HStack {
                        Text("Min download speed")
                        Spacer()
                        TextField("", value: $vm.config.minDownloadSpeed, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("Mbps")
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                    HStack {
                        Text("Connection timeout")
                        Spacer()
                        TextField("", value: $vm.config.connectionTimeout, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("sec")
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    /// Reusable stepper row with the live value displayed separately
    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, unit: String = "") -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue)\(unit.isEmpty ? "" : " \(unit)")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Paths

    private var isBundled: Bool {
        guard let res = Bundle.main.resourcePath else { return false }
        return FileManager.default.fileExists(atPath: res + "/python/vpn_tools/__init__.py")
    }

    private var pathSettings: some View {
        Form {
            Section("Speed test engine") {
                if isBundled {
                    Label("Bundled (self-contained)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Using external source", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    HStack {
                        TextField("Path", text: $vm.config.vpnToolsPath,
                                  prompt: Text("~/Documents/GitHub/vpn-tools"))
                        Button("Browse...") {
                            pickFolder()
                        }
                    }
                    if !vm.config.vpnToolsPath.isEmpty {
                        let exists = FileManager.default.fileExists(atPath: vm.config.vpnToolsPath + "/src/vpn_tools/mullvad_speed_test.py")
                        Label(
                            exists ? "Script found" : "mullvad_speed_test.py not found",
                            systemImage: exists ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(exists ? .green : .red)
                    }
                }
            }

            Section("Runtime data") {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let runtimePath = appSupport.appendingPathComponent("VPN Tools/runtime").path
                LabeledContent("Location") {
                    Text(runtimePath)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section("Python") {
                LabeledContent("Detected") {
                    Text(detectedPython.isEmpty ? "Not found" : detectedPython)
                        .foregroundStyle(detectedPython.isEmpty ? .red : .green)
                        .font(.body.monospaced())
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Helpers

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the vpn-tools project directory"

        if panel.runModal() == .OK, let url = panel.url {
            vm.config.vpnToolsPath = url.path
        }
    }

    private func detectPython() {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                detectedPython = path
                return
            }
        }
    }

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
