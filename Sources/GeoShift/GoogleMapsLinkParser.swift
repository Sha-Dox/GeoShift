import Foundation

enum MapsInput {
    case coordinate(latitude: Double, longitude: Double, label: String)
    case search(String)
}

enum GoogleMapsLinkParser {
    static func parse(_ text: String) async -> MapsInput? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let initialURL = URL(string: trimmed),
              let host = initialURL.host?.lowercased(),
              isGoogleMapsHost(host) else { return nil }

        let resolvedURL = await resolveIfShort(initialURL)
        let decoded = resolvedURL.absoluteString.removingPercentEncoding ?? resolvedURL.absoluteString

        // Google embeds the selected place as !3d<latitude>!4d<longitude>.
        // Prefer it over /@lat,lon, which can merely be the current viewport.
        if let coordinate = coordinates(in: decoded, pattern: #"!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)"#) {
            return .coordinate(latitude: coordinate.0, longitude: coordinate.1, label: placeLabel(from: resolvedURL))
        }
        if let coordinate = coordinates(in: decoded, pattern: #"/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)"#) {
            return .coordinate(latitude: coordinate.0, longitude: coordinate.1, label: placeLabel(from: resolvedURL))
        }

        if let components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) {
            // Prefer destination fields for directions links. Older Google Maps
            // share links use daddr/saddr; current Maps URLs use destination/origin.
            let usefulKeys = ["destination", "daddr", "query", "q", "ll", "center", "origin", "saddr"]
            for key in usefulKeys {
                guard let value = components.queryItems?.first(where: { $0.name.lowercased() == key })?.value,
                      !value.isEmpty else { continue }
                if let coordinate = coordinatePair(value) {
                    return .coordinate(latitude: coordinate.0, longitude: coordinate.1, label: "Google Maps pin")
                }
                return .search(value.replacingOccurrences(of: "+", with: " "))
            }
        }

        let label = placeLabel(from: resolvedURL)
        return label == "Google Maps pin" ? nil : .search(label)
    }

    private static func resolveIfShort(_ url: URL) async -> URL {
        guard let host = url.host?.lowercased(),
              host == "maps.app.goo.gl" || host == "goo.gl" else { return url }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 GeoShift", forHTTPHeaderField: "User-Agent")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response.url ?? url
        } catch {
            return url
        }
    }

    private static func isGoogleMapsHost(_ host: String) -> Bool {
        host == "maps.app.goo.gl" || host == "goo.gl" ||
        host == "maps.google.com" || host.hasSuffix(".google.com") ||
        host == "maps.google.co.uk" || host.hasPrefix("maps.google.")
    }

    private static func coordinates(in text: String, pattern: String) -> (Double, Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let latRange = Range(match.range(at: 1), in: text),
              let lonRange = Range(match.range(at: 2), in: text),
              let latitude = Double(text[latRange]),
              let longitude = Double(text[lonRange]),
              valid(latitude, longitude) else { return nil }
        return (latitude, longitude)
    }

    private static func coordinatePair(_ text: String) -> (Double, Double)? {
        let parts = text.split(separator: ",", maxSplits: 2).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, let latitude = Double(parts[0]), let longitude = Double(parts[1]),
              valid(latitude, longitude) else { return nil }
        return (latitude, longitude)
    }

    private static func valid(_ latitude: Double, _ longitude: Double) -> Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    private static func placeLabel(from url: URL) -> String {
        let components = url.pathComponents
        if let placeIndex = components.firstIndex(of: "place"), components.indices.contains(placeIndex + 1) {
            return components[placeIndex + 1]
                .removingPercentEncoding?
                .replacingOccurrences(of: "+", with: " ") ?? "Google Maps pin"
        }
        return "Google Maps pin"
    }
}
