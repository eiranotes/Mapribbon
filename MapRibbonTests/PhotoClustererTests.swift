import XCTest
@testable import MapRibbon

final class PhotoClustererTests: XCTestCase {
    func testNearbyPhotosBecomeOneCluster() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = [
            make(id: "a", date: start, latitude: 37.5665, longitude: 126.9780),
            make(id: "b", date: start.addingTimeInterval(600), latitude: 37.5668, longitude: 126.9783),
            make(id: "c", date: start.addingTimeInterval(1_200), latitude: 37.5670, longitude: 126.9781)
        ]
        XCTAssertEqual(PhotoClusterer.cluster(assets).count, 1)
    }

    func testDistantPhotosBecomeSeparateClusters() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = [
            make(id: "a", date: start, latitude: 37.5665, longitude: 126.9780),
            make(id: "b", date: start.addingTimeInterval(3_600), latitude: 35.1796, longitude: 129.0756)
        ]
        XCTAssertEqual(PhotoClusterer.cluster(assets).count, 2)
    }

    func testSameLocationAfterLongGapRemainsARevisit() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = [
            make(id: "hotel-morning", date: start, latitude: 35.6812, longitude: 139.7671),
            make(id: "museum", date: start.addingTimeInterval(2 * 3_600), latitude: 35.7148, longitude: 139.7967),
            make(id: "hotel-night", date: start.addingTimeInterval(9 * 3_600), latitude: 35.6813, longitude: 139.7670)
        ]
        let clusters = PhotoClusterer.cluster(assets)
        XCTAssertEqual(clusters.count, 3)
        XCTAssertEqual(clusters.first?.assets.first?.id, "hotel-morning")
        XCTAssertEqual(clusters.last?.assets.first?.id, "hotel-night")
    }

    func testSameLocationWithinShortContinuousVisitMerges() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = [
            make(id: "a", date: start, latitude: 35.6812, longitude: 139.7671),
            make(id: "b", date: start.addingTimeInterval(50 * 60), latitude: 35.6813, longitude: 139.7670)
        ]
        XCTAssertEqual(PhotoClusterer.cluster(assets).count, 1)
    }

    private func make(id: String, date: Date, latitude: Double, longitude: Double) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(
            id: id,
            creationDate: date,
            latitude: latitude,
            longitude: longitude,
            pixelWidth: 4_032,
            pixelHeight: 3_024,
            isFavorite: false,
            isScreenshot: false
        )
    }
}
