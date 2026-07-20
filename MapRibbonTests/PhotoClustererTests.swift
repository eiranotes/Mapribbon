import XCTest
import CoreGraphics
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

    func testGeoSeededLayoutAvoidsPhotoOverlap() {
        let geoPoints = [
            CGPoint(x: 0.16, y: 0.18), CGPoint(x: 0.80, y: 0.24), CGPoint(x: 0.38, y: 0.50),
            CGPoint(x: 0.18, y: 0.76), CGPoint(x: 0.82, y: 0.84)
        ]
        for aspectRatio in [CGFloat(9.0 / 16.0), 3.0 / 4.0, 4.0 / 5.0] {
            let placements = BoardLayoutEngine.placements(count: geoPoints.count, geoPoints: geoPoints, aspectRatio: aspectRatio)
            XCTAssertEqual(placements.count, geoPoints.count)
            assertNoOverlap(placements, aspectRatio: aspectRatio)
        }
    }

    func testDegenerateGeoPointsStillProduceValidLayout() {
        let samePoint = Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 5)
        let placements = BoardLayoutEngine.placements(count: 5, geoPoints: samePoint, aspectRatio: 3.0 / 4.0)
        XCTAssertEqual(placements.count, 5)
        assertNoOverlap(placements, aspectRatio: 3.0 / 4.0)
    }

    private func assertNoOverlap(_ placements: [BoardCardPlacement], aspectRatio: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        guard let cardWidth = placements.first?.widthFactor else { return }
        let cardHeight = cardWidth * BoardLayoutEngine.cardHeightRatio * aspectRatio
        for i in placements.indices {
            for j in placements.indices where j > i {
                let dx = abs(placements[j].center.x - placements[i].center.x)
                let dy = abs(placements[j].center.y - placements[i].center.y)
                XCTAssertFalse(
                    dx < cardWidth * 0.90 && dy < cardHeight * 0.88,
                    "cards \(i) and \(j) overlap: dx=\(dx), dy=\(dy)",
                    file: file,
                    line: line
                )
            }
        }
    }

    func testThreadPaletteProvidesDistinctRenderColors() {
        XCTAssertEqual(BoardThreadColor.allCases.count, 6)
        XCTAssertEqual(Set(BoardThreadColor.allCases.map(\.primaryHex)).count, 6)
        XCTAssertTrue(BoardThreadColor.allCases.allSatisfy { $0.primaryHex != $0.highlightHex })
    }

    private func make(id: String, date: Date, latitude: Double, longitude: Double) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(id: id, creationDate: date, latitude: latitude, longitude: longitude, pixelWidth: 4_032, pixelHeight: 3_024, isFavorite: false, isScreenshot: false)
    }
}
