import XCTest
@testable import GeoShift

final class GoogleMapsLinkParserTests: XCTestCase {
    func testSelectedPlaceCoordinatesBeatViewport() async {
        let url = "https://www.google.com/maps/place/Eiffel+Tower/@48.8582,2.2923,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d48.8583701!4d2.2944813"
        guard case let .coordinate(latitude, longitude, label) = await GoogleMapsLinkParser.parse(url) else {
            return XCTFail("Expected coordinates")
        }
        XCTAssertEqual(latitude, 48.8583701, accuracy: 0.0000001)
        XCTAssertEqual(longitude, 2.2944813, accuracy: 0.0000001)
        XCTAssertEqual(label, "Eiffel Tower")
    }

    func testCoordinateQueryURL() async {
        let url = "https://www.google.com/maps/search/?api=1&query=40.6892%2C-74.0445"
        guard case let .coordinate(latitude, longitude, _) = await GoogleMapsLinkParser.parse(url) else {
            return XCTFail("Expected coordinates")
        }
        XCTAssertEqual(latitude, 40.6892, accuracy: 0.0000001)
        XCTAssertEqual(longitude, -74.0445, accuracy: 0.0000001)
    }

    func testPlaceQueryFallsBackToMapSearch() async {
        let url = "https://www.google.com/maps/search/?api=1&query=Grand+Central+Terminal"
        guard case let .search(query) = await GoogleMapsLinkParser.parse(url) else {
            return XCTFail("Expected a search query")
        }
        XCTAssertEqual(query, "Grand Central Terminal")
    }

    func testLegacyDirectionsLinkUsesDestination() async {
        let url = "https://www.google.com/maps?daddr=40.6892494,-74.0445004&saddr=40.7812199,-73.9665138&dirflg=d"
        guard case let .coordinate(latitude, longitude, _) = await GoogleMapsLinkParser.parse(url) else {
            return XCTFail("Expected destination coordinates")
        }
        XCTAssertEqual(latitude, 40.6892494, accuracy: 0.0000001)
        XCTAssertEqual(longitude, -74.0445004, accuracy: 0.0000001)
    }

    func testFullGoogleMapsDirectionsShareLink() async {
        let url = "https://www.google.com/maps?daddr=40.6892494,-74.0445004&saddr=40.7812199,-73.9665138&dirflg=d&lucs=example&g_ep=example"
        guard case let .coordinate(latitude, longitude, _) = await GoogleMapsLinkParser.parse(url) else {
            return XCTFail("Expected full share-link destination coordinates")
        }
        XCTAssertEqual(latitude, 40.6892494, accuracy: 0.0000001)
        XCTAssertEqual(longitude, -74.0445004, accuracy: 0.0000001)
    }
}
