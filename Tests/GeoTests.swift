import XCTest
@testable import PollenAlertApp

final class GeoTests: XCTestCase {
    func testLatLonToH3() {
        let lat = 55.7558
        let lon = 37.6173
        let h3Index = GeoUtils.latLonToH3(lat: lat, lon: lon)
        
        XCTAssertFalse(h3Index.isEmpty, "H3 индекс не должен быть пустым")
        // Когда будет подключена H3Swift, можно будет проверить на валидность:
        // XCTAssertTrue(H3Index(h3Index).isValid)
    }
}

