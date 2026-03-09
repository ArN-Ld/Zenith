import Foundation

/// A resolved location with city, country, continent, and coordinates
struct ResolvedLocation {
    let city: String
    let country: String
    let continent: String
    let latitude: Double
    let longitude: Double

    var displayName: String {
        city + (country.isEmpty ? "" : ", \(country)")
    }
}

/// Resolves location input against the Mullvad server coordinates database,
/// providing instant and accurate results without relying on CLGeocoder.
final class LocationResolver {
    static let shared = LocationResolver()

    private var locations: [String: [Double]] = [:]
    private var cityIndex: [String: [(fullName: String, lat: Double, lon: Double)]] = [:]

    private init() {
        loadCoordinates()
    }

    private func loadCoordinates() {
        let candidates: [String?] = [
            Bundle.main.resourcePath.map { $0 + "/python/vpn_tools/data/coordinates.json" },
            FileManager.default.homeDirectoryForCurrentUser.path
                + "/Documents/GitHub/vpn-tools/src/vpn_tools/data/coordinates.json"
        ]

        for path in candidates.compactMap({ $0 }) {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [Double]] else { continue }

            locations = json
            for (name, coords) in json where coords.count >= 2 {
                let city = name.components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                if !city.isEmpty {
                    cityIndex[city, default: []].append((name, coords[0], coords[1]))
                }
            }
            return
        }
    }

    /// Search for locations matching a prefix (for autocomplete suggestions).
    /// Returns up to `limit` matches sorted alphabetically by city name.
    func search(_ prefix: String, limit: Int = 6) -> [ResolvedLocation] {
        let lower = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lower.count >= 3 else { return [] }

        var results: [ResolvedLocation] = []
        var seen = Set<String>()

        // 1. City-name prefix match (e.g. "barce" → Barcelona)
        for (city, entries) in cityIndex {
            if city.hasPrefix(lower) {
                for entry in entries {
                    let key = entry.fullName.lowercased()
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    results.append(makeResult(name: entry.fullName, lat: entry.lat, lon: entry.lon))
                }
            }
        }

        // 2. Full-name substring match (e.g. "york" → New York)
        for (name, coords) in locations where coords.count >= 2 {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            if key.contains(lower) {
                seen.insert(key)
                results.append(makeResult(name: name, lat: coords[0], lon: coords[1]))
            }
        }

        return Array(results.sorted { $0.city < $1.city }.prefix(limit))
    }

    /// Resolve user input against known Mullvad server locations.
    /// Returns nil if no match is found (caller should fall back to CLGeocoder).
    func resolve(_ input: String) -> ResolvedLocation? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // 1. Exact full match ("Madrid, Spain")
        for (name, coords) in locations where coords.count >= 2 {
            if name.lowercased() == lower {
                return makeResult(name: name, lat: coords[0], lon: coords[1])
            }
        }

        // 2. Extract city token from input
        let inputCity = lower.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? lower

        // 3. Exact city name match
        if let matches = cityIndex[inputCity], let first = matches.first {
            return makeResult(name: first.fullName, lat: first.lat, lon: first.lon)
        }

        return nil
    }

    private func makeResult(name: String, lat: Double, lon: Double) -> ResolvedLocation {
        let parts = name.components(separatedBy: ",")
        let city = parts.first?.trimmingCharacters(in: .whitespaces) ?? name
        let country = parts.count >= 2
            ? parts.last!.trimmingCharacters(in: .whitespaces)
            : ""
        let continent = Self.countryContinent[country] ?? ""
        return ResolvedLocation(city: city, country: country, continent: continent,
                                latitude: lat, longitude: lon)
    }

    // MARK: - Continent mapping

    /// Country name → continent (covers all countries in Mullvad coordinates.json)
    private static let countryContinent: [String: String] = [
        "Australia": "Oceania", "New Zealand": "Oceania",
        "Canada": "North America", "USA": "North America", "Mexico": "North America",
        "UK": "Europe", "Netherlands": "Europe", "France": "Europe", "Germany": "Europe",
        "Belgium": "Europe", "Denmark": "Europe", "Sweden": "Europe", "Norway": "Europe",
        "Finland": "Europe", "Switzerland": "Europe", "Austria": "Europe", "Spain": "Europe",
        "Italy": "Europe", "Poland": "Europe", "Czech Republic": "Europe", "Hungary": "Europe",
        "Romania": "Europe", "Bulgaria": "Europe", "Greece": "Europe", "Albania": "Europe",
        "Ireland": "Europe", "Portugal": "Europe", "Croatia": "Europe", "Serbia": "Europe",
        "Slovenia": "Europe", "Slovakia": "Europe", "Estonia": "Europe", "Cyprus": "Europe",
        "Turkey": "Europe", "Ukraine": "Europe",
        "Japan": "Asia", "Singapore": "Asia", "Hong Kong": "Asia", "South Korea": "Asia",
        "Taiwan": "Asia", "Thailand": "Asia", "Indonesia": "Asia", "Malaysia": "Asia",
        "Philippines": "Asia", "Israel": "Asia", "China": "Asia",
        "Argentina": "South America", "Brazil": "South America", "Chile": "South America",
        "Colombia": "South America", "Peru": "South America",
        "Nigeria": "Africa", "South Africa": "Africa",
    ]

    /// Map ISO 3166-1 alpha-2 country code to continent name (for CLGeocoder fallback)
    static func continentFromCode(_ code: String?) -> String {
        guard let c = code?.uppercased() else { return "" }
        switch c {
        case "JP","KR","CN","HK","TW","SG","MY","TH","VN","ID","PH","IN","IL","KH","MM","LA","BD","PK","LK","NP","MN":
            return "Asia"
        case "AU","NZ","FJ","PG":
            return "Oceania"
        case "US","CA","MX","GT","HN","PA","CR","CU","JM","TT","DO":
            return "North America"
        case "BR","AR","CL","CO","PE","EC","VE","UY","PY","BO":
            return "South America"
        case "ZA","NG","EG","KE","MA","TZ","GH","ET","CM","DZ","TN","SN":
            return "Africa"
        default:
            let european: Set<String> = [
                "GB","DE","FR","IT","ES","NL","SE","NO","DK","FI","CH","AT","BE","IE","PT",
                "PL","CZ","RO","HU","GR","HR","RS","SI","SK","EE","LT","LV","BG","AL",
                "UA","TR","CY","IS","LU","MT","MK","ME","BA","MD"
            ]
            return european.contains(c) ? "Europe" : ""
        }
    }
}
