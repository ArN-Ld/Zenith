import Foundation

/// Checks GitHub Releases for a newer version and total download count.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var latestVersion: String? = nil
    @Published var lastError: String? = nil
    @Published var totalDownloads: Int? = nil

    let currentVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private var lastChecked: Date? = nil

    func check(force: Bool = false) async {
        guard !isChecking else { return }
        if !force, let last = lastChecked, Date().timeIntervalSince(last) < 60 { return }
        isChecking = true
        lastError = nil
        defer {
            isChecking = false
            lastChecked = Date()
        }
        do {
            // Fetch all releases: covers latest version + total download count
            var req = URLRequest(
                url: URL(string: "https://api.github.com/repos/ArN-Ld/Zenith/releases")!
            )
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            req.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: req)

            struct Asset: Decodable { let download_count: Int }
            struct Release: Decodable {
                let tag_name: String
                let assets: [Asset]
            }
            let releases = try JSONDecoder().decode([Release].self, from: data)

            // Latest is the first published release
            if let first = releases.first {
                let latest = first.tag_name
                    .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                latestVersion = latest
                updateAvailable =
                    latest.compare(currentVersion, options: .numeric) == .orderedDescending
            }
            // Sum all asset downloads across all releases
            totalDownloads = releases
                .flatMap(\.assets)
                .map(\.download_count)
                .reduce(0, +)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
