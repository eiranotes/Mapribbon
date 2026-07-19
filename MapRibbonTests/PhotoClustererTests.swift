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


    func testReferenceRibbonUsesBranchedRouteGraph() {
        let edges = BoardRouteLayout.edgePairs(for: 5).map { [$0.0, $0.1] }
        XCTAssertEqual(edges, [[0, 1], [0, 2], [2, 3], [1, 4], [3, 4]])
    }

    func testReferenceRibbonExtendsSequentiallyAfterFivePlaces() {
        let edges = BoardRouteLayout.edgePairs(for: 7).map { [$0.0, $0.1] }
        XCTAssertEqual(edges.suffix(2), [[4, 5], [5, 6]])
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
