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

    func testAllSupportedCountsAvoidOverlapAcrossExportRatios() {
        let aspectRatios: [CGFloat] = [9.0 / 16.0, 4.0 / 5.0, 3.0 / 4.0]
        for count in 1...8 {
            for aspectRatio in aspectRatios {
                let points = Array(sampleGeoPoints.prefix(count))
                let placements = BoardLayoutEngine.placements(count: count, geoPoints: points, aspectRatio: aspectRatio)
                XCTAssertEqual(placements.count, count)
                assertNoOverlap(placements, aspectRatio: aspectRatio)
                assertInsideBounds(placements, aspectRatio: aspectRatio)
            }
        }
    }

    func testGeoSeededLayoutDoesNotDriftExcessively() {
        let geographicSample = Array(sampleGeoPoints.prefix(5))
        let placements = BoardLayoutEngine.placements(
            count: geographicSample.count,
            geoPoints: geographicSample,
            aspectRatio: 3.0 / 4.0
        )
        for (placement, seed) in zip(placements, geographicSample) {
            let displacement = hypot(placement.center.x - seed.x, placement.center.y - seed.y)
            XCTAssertLessThanOrEqual(displacement, BoardLayoutEngine.maxGeoDisplacement + 0.02)
        }
    }

    func testDegenerateGeoPointsFallBackToValidLayout() {
        let samePoint = Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 5)
        let placements = BoardLayoutEngine.placements(count: 5, geoPoints: samePoint, aspectRatio: 3.0 / 4.0)
        XCTAssertEqual(placements.count, 5)
        assertNoOverlap(placements, aspectRatio: 3.0 / 4.0)
    }

    func testAspectFillPointAdjustmentMatchesMapCropping() {
        let points = [CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.75)]
        let story = BoardLayoutEngine.adjustedForAspectFill(points, sourceAspectRatio: 3.0 / 4.0, targetAspectRatio: 9.0 / 16.0)
        XCTAssertEqual(story[0].x, 1.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(story[1].x, 5.0 / 6.0, accuracy: 0.001)

        let feed = BoardLayoutEngine.adjustedForAspectFill(points, sourceAspectRatio: 3.0 / 4.0, targetAspectRatio: 4.0 / 5.0)
        XCTAssertEqual(feed[0].y, 0.2333, accuracy: 0.001)
        XCTAssertEqual(feed[1].y, 0.7667, accuracy: 0.001)
    }

    func testThreadPaletteProvidesDistinctRenderColors() {
        XCTAssertEqual(BoardThreadColor.allCases.count, 6)
        XCTAssertEqual(Set(BoardThreadColor.allCases.map(\.primaryHex)).count, 6)
        XCTAssertTrue(BoardThreadColor.allCases.allSatisfy { $0.primaryHex != $0.highlightHex })
    }

    func testRegionNormalizerCoversAllJapanesePrefectures() {
        let samples: [(String, String)] = [
            ("北海道", "일본:홋카이도"),
            ("青森県", "일본:도호쿠"), ("岩手県", "일본:도호쿠"), ("宮城県", "일본:도호쿠"), ("秋田県", "일본:도호쿠"), ("山形県", "일본:도호쿠"), ("福島県", "일본:도호쿠"),
            ("茨城県", "일본:간토"), ("栃木県", "일본:간토"), ("群馬県", "일본:간토"), ("埼玉県", "일본:간토"), ("千葉県", "일본:간토"), ("東京都", "일본:간토"), ("神奈川県", "일본:간토"),
            ("新潟県", "일본:주부"), ("富山県", "일본:주부"), ("石川県", "일본:주부"), ("福井県", "일본:주부"), ("山梨県", "일본:주부"), ("長野県", "일본:주부"), ("岐阜県", "일본:주부"), ("静岡県", "일본:주부"), ("愛知県", "일본:주부"),
            ("三重県", "일본:간사이"), ("滋賀県", "일본:간사이"), ("京都府", "일본:간사이"), ("大阪府", "일본:간사이"), ("兵庫県", "일본:간사이"), ("奈良県", "일본:간사이"), ("和歌山県", "일본:간사이"),
            ("鳥取県", "일본:주고쿠"), ("島根県", "일본:주고쿠"), ("岡山県", "일본:주고쿠"), ("広島県", "일본:주고쿠"), ("山口県", "일본:주고쿠"),
            ("徳島県", "일본:시코쿠"), ("香川県", "일본:시코쿠"), ("愛媛県", "일본:시코쿠"), ("高知県", "일본:시코쿠"),
            ("福岡県", "일본:규슈"), ("佐賀県", "일본:규슈"), ("長崎県", "일본:규슈"), ("熊本県", "일본:규슈"), ("大分県", "일본:규슈"), ("宮崎県", "일본:규슈"), ("鹿児島県", "일본:규슈"), ("沖縄県", "일본:규슈")
        ]

        XCTAssertEqual(samples.count, 47)
        for (administrativeArea, expected) in samples {
            XCTAssertEqual(RegionNormalizer.key(from: administrativeArea), expected, administrativeArea)
        }
    }

    func testRegionNormalizerAcceptsEnglishPrefectureNames() {
        XCTAssertEqual(RegionNormalizer.key(from: "Toyama Prefecture"), "일본:주부")
        XCTAssertEqual(RegionNormalizer.key(from: "Wakayama Prefecture"), "일본:간사이")
        XCTAssertEqual(RegionNormalizer.key(from: "Yamaguchi Prefecture"), "일본:주고쿠")
        XCTAssertEqual(RegionNormalizer.key(from: "Kochi Prefecture"), "일본:시코쿠")
        XCTAssertEqual(RegionNormalizer.key(from: "Oita Prefecture"), "일본:규슈")
    }

    func testBoardRegionSummaryPreservesVisibleTravelOrder() {
        let places = [
            makePlace(title: "숨김", administrativeArea: "서울특별시", isHidden: true),
            makePlace(title: "오사카", administrativeArea: "Osaka Prefecture"),
            makePlace(title: "도쿄", administrativeArea: "Tokyo Metropolis"),
            makePlace(title: "교토", administrativeArea: "京都府")
        ]

        XCTAssertEqual(BoardRegionSummary.regionKeys(from: places), ["일본:간사이", "일본:간토"])
        XCTAssertEqual(BoardRegionSummary.primaryRegion(from: places), "일본:간사이")
    }

    func testAtlasCoverageKeepsLegacyFallbackRegions() {
        let missing = AtlasVisitCoverage.missingRegionKeys(
            visited: ["일본:간토", "일본:간사이", "일본:규슈"],
            actual: ["일본:간토"],
            country: .japan
        )
        XCTAssertEqual(missing, ["일본:간사이", "일본:규슈"])
    }

    private var sampleGeoPoints: [CGPoint] {
        [
            CGPoint(x: 0.16, y: 0.18), CGPoint(x: 0.80, y: 0.24),
            CGPoint(x: 0.38, y: 0.50), CGPoint(x: 0.18, y: 0.76),
            CGPoint(x: 0.82, y: 0.84), CGPoint(x: 0.68, y: 0.62),
            CGPoint(x: 0.47, y: 0.72), CGPoint(x: 0.84, y: 0.48)
        ]
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

    private func assertInsideBounds(_ placements: [BoardCardPlacement], aspectRatio: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        for placement in placements {
            let halfWidth = placement.widthFactor / 2
            let halfHeight = placement.widthFactor * BoardLayoutEngine.cardHeightRatio * aspectRatio / 2
            XCTAssertGreaterThanOrEqual(placement.center.x - halfWidth, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(placement.center.x + halfWidth, 1, file: file, line: line)
            XCTAssertGreaterThanOrEqual(placement.center.y - halfHeight, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(placement.center.y + halfHeight, 1, file: file, line: line)
        }
    }

    private func makePlace(
        title: String,
        administrativeArea: String,
        isHidden: Bool = false
    ) -> BoardPlace {
        let identifier = UUID().uuidString
        return BoardPlace(
            id: UUID(),
            title: title,
            subtitle: nil,
            caption: nil,
            addressSummary: administrativeArea,
            administrativeArea: administrativeArea,
            locality: nil,
            latitude: 35.0,
            longitude: 135.0,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_003_600),
            assetIdentifiers: [identifier],
            representativeAssetIdentifier: identifier,
            isHidden: isHidden
        )
    }

    private func make(id: String, date: Date, latitude: Double, longitude: Double) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(id: id, creationDate: date, latitude: latitude, longitude: longitude, pixelWidth: 4_032, pixelHeight: 3_024, isFavorite: false, isScreenshot: false)
    }
}
