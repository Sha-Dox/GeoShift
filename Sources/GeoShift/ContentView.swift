import AppKit
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var device = DeviceLocationService()
    @StateObject private var locations = LocationStore()
    @State private var selected = Place(name: "Apple Park", latitude: 37.3349, longitude: -122.0090)
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var latitudeText = "37.3349000"
    @State private var longitudeText = "-122.0090000"
    @State private var showSetup = true
    @State private var searchMessage = "Paste or drag in a Google Maps link"

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 380)
            Divider()
            mapPanel
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await device.monitorConnection() }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("GeoShift", systemImage: "location.fill.viewfinder")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("USB location testing for your iPhone")
                        .foregroundStyle(.secondary)
                }

                Label("Auto-connect is on", systemImage: "bolt.horizontal.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)

                statusCard
                coordinateCard
                quickPlaces
                savedPlaces
                setupCard

                Text("For development and personal testing. Apps can identify a location as software-simulated, and their terms may restrict its use.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusTitle)
                    .font(.headline)
                Spacer()
                Button {
                    Task { await device.checkConnection() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(device.isWorking)
            }
            Text(device.lastMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !device.deviceDetails.isEmpty {
                Label(device.deviceDetails, systemImage: "cable.connector")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var coordinateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pinned location")
                .font(.headline)
            HStack {
                field("Latitude", text: $latitudeText)
                field("Longitude", text: $longitudeText)
            }

            HStack {
                Button {
                    locations.toggleFavorite(selected)
                } label: {
                    Label(locations.isFavorite(selected) ? "Favorited" : "Favorite", systemImage: locations.isFavorite(selected) ? "star.fill" : "star")
                }
                Button {
                    copyCoordinates()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    openInMaps()
                } label: {
                    Label("Maps", systemImage: "map")
                }
            }
            .buttonStyle(.borderless)

            Button {
                syncPinFromFields()
                Task {
                    if await device.setLocation(latitude: selected.latitude, longitude: selected.longitude) {
                        locations.record(selected)
                    }
                }
            } label: {
                HStack {
                    if device.isWorking { ProgressView().controlSize(.small) }
                    Text("Apply to iPhone")
                    Spacer()
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.indigo)
            .disabled(device.isWorking || !coordinatesAreValid)

            Button(role: .destructive) {
                Task { await device.restoreRealLocation() }
            } label: {
                Label("Restore real GPS", systemImage: "location.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(device.isWorking)
        }
        .cardStyle()
    }

    private var quickPlaces: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick places")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Place.defaults) { place in
                    Button(place.name) { choose(place) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var savedPlaces: some View {
        if !locations.favorites.isEmpty || !locations.recents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !locations.favorites.isEmpty {
                    Text("Favorites")
                        .font(.headline)
                    ForEach(locations.favorites.prefix(5)) { place in
                        placeRow(place, icon: "star.fill")
                    }
                }

                if !locations.recents.isEmpty {
                    HStack {
                        Text("Recent")
                            .font(.headline)
                        Spacer()
                        Button("Clear") { locations.clearRecents() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(locations.recents.prefix(5)) { place in
                        placeRow(place, icon: "clock")
                    }
                }
            }
        }
    }

    private func placeRow(_ place: Place, icon: String) -> some View {
        Button {
            choose(place)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).lineLimit(1)
                    Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var setupCard: some View {
        DisclosureGroup("One-time setup", isExpanded: $showSetup) {
            VStack(alignment: .leading, spacing: 10) {
                setupRow(1, "Connect by USB, unlock, and tap Trust")
                setupRow(2, "Enable Settings › Privacy & Security › Developer Mode")
                setupRow(3, "Open Xcode once so device support can finish")
                setupRow(4, "Let GeoShift install its private phone bridge")
                Text("No Terminal or shell configuration. The runtime stays inside your Application Support folder and can be repaired here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let progress = device.setupProgress {
                    ProgressView(value: progress)
                }
                if !device.setupStatus.isEmpty {
                    Text(device.setupStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await device.installOrRepairRuntime() }
                } label: {
                    Label(setupButtonTitle, systemImage: "wrench.and.screwdriver.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(device.isWorking)

                Button("Copy diagnostics") { device.copyDiagnostics() }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
            .padding(.top, 12)
        }
        .cardStyle()
    }

    private var mapPanel: some View {
        ZStack(alignment: .top) {
            MapReader { proxy in
                Map(position: $camera) {
                    Marker(selected.name, coordinate: CLLocationCoordinate2D(latitude: selected.latitude, longitude: selected.longitude))
                        .tint(.indigo)
                }
                .mapStyle(.standard(elevation: .realistic))
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        if let coordinate = proxy.convert(value.location, from: .local) {
                            choose(Place(name: "Dropped pin", latitude: coordinate.latitude, longitude: coordinate.longitude), moveCamera: false)
                        }
                    }
                )
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search, address, or Google Maps link", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await importOrSearch() } }
                    if !searchText.isEmpty {
                        Button { searchText = ""; searchResults = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    searchText = url.absoluteString
                    Task { await importOrSearch() }
                    return true
                }

                if !searchResults.isEmpty {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                let coordinate = item.placemark.coordinate
                                choose(Place(name: item.name ?? "Search result", latitude: coordinate.latitude, longitude: coordinate.longitude))
                                searchResults = []
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "Unknown place")
                                        Text(item.placemark.title ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 5)
            .padding(20)
            .frame(maxWidth: 560)

            Text(searchMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, searchResults.isEmpty ? 78 : 300)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("Click anywhere to drop the pin")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(20)
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { syncPinFromFields() }
        }
    }

    private func setupRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(.indigo.opacity(0.15), in: Circle())
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var coordinatesAreValid: Bool {
        guard let lat = Double(latitudeText), let lon = Double(longitudeText) else { return false }
        return (-90...90).contains(lat) && (-180...180).contains(lon)
    }

    private var statusTitle: String {
        switch device.connectionState {
        case .checking: return "Checking connection"
        case .ready(let name): return name
        case .missingTool: return "Setup needed"
        case .noDevice: return "iPhone not found"
        case .error: return "Connection issue"
        }
    }

    private var statusColor: Color {
        switch device.connectionState {
        case .ready: return .green
        case .checking: return .orange
        default: return .red
        }
    }

    private var setupButtonTitle: String {
        switch device.connectionState {
        case .missingTool: return "Set Up Automatically"
        default: return "Repair or Update Setup"
        }
    }

    private func copyCoordinates() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            String(format: "%.7f, %.7f", selected.latitude, selected.longitude),
            forType: .string
        )
    }

    private func openInMaps() {
        let encodedName = selected.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Pin"
        guard let url = URL(string: "https://maps.apple.com/?ll=\(selected.latitude),\(selected.longitude)&q=\(encodedName)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func choose(_ place: Place, moveCamera: Bool = true) {
        selected = place
        latitudeText = String(format: "%.7f", place.latitude)
        longitudeText = String(format: "%.7f", place.longitude)
        if moveCamera {
            withAnimation {
                camera = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                ))
            }
        }
    }

    private func syncPinFromFields() {
        guard let lat = Double(latitudeText), let lon = Double(longitudeText),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return }
        choose(Place(name: "Custom location", latitude: lat, longitude: lon))
    }

    private func importOrSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let mapsInput = await GoogleMapsLinkParser.parse(searchText) {
            switch mapsInput {
            case .coordinate(let latitude, let longitude, let label):
                choose(Place(name: label, latitude: latitude, longitude: longitude))
                searchResults = []
                searchMessage = "Google Maps location imported"
                return
            case .search(let query):
                await search(query)
                return
            }
        }
        await search(searchText)
    }

    private func search(_ query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = Array(response.mapItems.prefix(5))
            searchMessage = searchResults.isEmpty ? "No matching place found" : "Choose a search result"
        } catch {
            searchResults = []
            searchMessage = "Couldn’t search that location"
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }
}
