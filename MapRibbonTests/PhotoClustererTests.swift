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

    func testRibbonRoutePreservesChronologicalOrder() {
        let edges = BoardRouteLayout.edgePairs(for: 5).map { [$0.0, $0.1] }
        XCTAssertEqual(edges, [[0, 1], [1, 2], [2, 3], [3, 4]])
    }

    func testPosterLayoutProvidesFiveDistinctPlacements() {
        let placements = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 3.0 / 4.0)
        XCTAssertEqual(placements.count, 5)
        XCTAssertEqual(Set(placements.map { "\($0.center.x)-\($0.center.y)" }).count, 5)
    }

    func testStoryLayoutUsesLargerCardsThanPoster() {
        let story = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 9.0 / 16.0)
        let poster = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 3.0 / 4.0)
        XCTAssertGreaterThan(story[0].widthFactor, poster[0].widthFactor)
    }

    private func make(id: String, date: Date, latitude: Double, longitude: Double) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(id: id, creationDate: date, latitude: latitude, longitude: longitude, pixelWidth: 4_032, pixelHeight: 3_024, isFavorite: false, isScreenshot: false)
    }
}
