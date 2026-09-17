import Foundation

struct Place: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    static let defaults = [
        Place(name: "New York", latitude: 40.7128, longitude: -74.0060),
        Place(name: "London", latitude: 51.5074, longitude: -0.1278),
        Place(name: "Paris", latitude: 48.8566, longitude: 2.3522),
        Place(name: "Tokyo", latitude: 35.6762, longitude: 139.6503)
    ]
}

@MainActor
final class LocationStore: ObservableObject {
    @Published private(set) var favorites: [Place] = []
    @Published private(set) var recents: [Place] = []

    private let favoritesKey = "GeoShift.favorites.v1"
    private let recentsKey = "GeoShift.recents.v1"

    init() {
        favorites = load(favoritesKey)
        recents = load(recentsKey)
    }

    func isFavorite(_ place: Place) -> Bool {
        favorites.contains { close($0, place) }
    }

    func toggleFavorite(_ place: Place) {
        if let index = favorites.firstIndex(where: { close($0, place) }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(place, at: 0)
        }
        save(favorites, key: favoritesKey)
    }

    func record(_ place: Place) {
        recents.removeAll { close($0, place) }
        recents.insert(place, at: 0)
        recents = Array(recents.prefix(8))
        save(recents, key: recentsKey)
    }

    func clearRecents() {
        recents = []
        save(recents, key: recentsKey)
    }

    private func close(_ lhs: Place, _ rhs: Place) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.000001 && abs(lhs.longitude - rhs.longitude) < 0.000001
    }

    private func load(_ key: String) -> [Place] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Place].self, from: data)) ?? []
    }

    private func save(_ places: [Place], key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(places), forKey: key)
    }
}
