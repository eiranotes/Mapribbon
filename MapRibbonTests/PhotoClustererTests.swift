import XCTest
import UIKit
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

    func testMultiplePhotosAtEachStopRemainGroupedAndPreserved() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let stops: [(Double, Double, TimeInterval)] = [
            (37.5663, 126.9779, 0),
            (37.5796, 126.9770, 2 * 3_600),
            (37.5702, 126.9997, 5 * 3_600),
            (37.5663, 126.9780, 10 * 3_600)
        ]

        var assets: [PhotoAssetSnapshot] = []
        for (stopIndex, stop) in stops.enumerated() {
            for photoIndex in 0..<3 {
                assets.append(make(
                    id: "stop-\(stopIndex)-photo-\(photoIndex)",
                    date: start.addingTimeInterval(stop.2 + Double(photoIndex) * 12 * 60),
                    latitude: stop.0 + Double(photoIndex) * 0.00005,
                    longitude: stop.1 + Double(photoIndex) * 0.00005
                ))
            }
        }

        let clusters = PhotoClusterer.cluster(assets)

        XCTAssertEqual(clusters.count, 4)
        XCTAssertEqual(clusters.map { $0.assets.count }, [3, 3, 3, 3])
        XCTAssertEqual(clusters.flatMap(\.assets).count, 12)
        XCTAssertEqual(Set(clusters.flatMap(\.assets).map(\.id)), Set(assets.map(\.id)))
    }

    func testRepresentativePrefersFavoriteWithinPhotoStack() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let normal = make(id: "normal", date: start, latitude: 37.56, longitude: 126.97)
        let favorite = make(
            id: "favorite",
            date: start.addingTimeInterval(15 * 60),
            latitude: 37.5601,
            longitude: 126.9701,
            isFavorite: true
        )
        let later = make(id: "later", date: start.addingTimeInterval(30 * 60), latitude: 37.5602, longitude: 126.9702)

        XCTAssertEqual(PhotoClusterer.representative(in: [normal, favorite, later])?.id, "favorite")
    }

    @MainActor
    func testMovingPhotoBetweenPlacesKeepsSingleOwner() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = [
            make(id: "a", date: start, latitude: 37.56, longitude: 126.97),
            make(id: "b", date: start.addingTimeInterval(300), latitude: 37.56, longitude: 126.97),
            make(id: "c", date: start.addingTimeInterval(3_600), latitude: 37.58, longitude: 126.99)
        ]
        let first = makePlace(id: UUID(), title: "A", assets: [assets[0], assets[1]])
        let second = makePlace(id: UUID(), title: "B", assets: [assets[2]])
        let draft = makeDraft(assets: assets, places: [first, second])

        draft.toggleAsset("b", for: second.id)

        XCTAssertFalse(draft.places[0].assetIdentifiers.contains("b"))
        XCTAssertTrue(draft.places[1].assetIdentifiers.contains("b"))
        XCTAssertEqual(draft.places.flatMap(\.assetIdentifiers).filter { $0 == "b" }.count, 1)
    }

    @MainActor
    func testCannotRemoveLastPhotoFromPlace() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = make(id: "only", date: start, latitude: 37.56, longitude: 126.97)
        let place = makePlace(id: UUID(), title: "Only", assets: [asset])
        let draft = makeDraft(assets: [asset], places: [place])

        draft.toggleAsset("only", for: place.id)

        XCTAssertEqual(draft.places[0].assetIdentifiers, ["only"])
    }

    @MainActor
    func testSplitPlaceUsesLargestTimeGap() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assets = [
            make(id: "a", date: start, latitude: 37.56, longitude: 126.97),
            make(id: "b", date: start.addingTimeInterval(20 * 60), latitude: 37.56, longitude: 126.97),
            make(id: "c", date: start.addingTimeInterval(3 * 3_600), latitude: 37.56, longitude: 126.97)
        ]
        let place = makePlace(id: UUID(), title: "Split", assets: assets)
        let draft = makeDraft(assets: assets, places: [place])

        XCTAssertTrue(draft.splitPlace(place.id))
        XCTAssertEqual(draft.places.count, 2)
        XCTAssertEqual(draft.places[0].assetIdentifiers, ["a", "b"])
        XCTAssertEqual(draft.places[1].assetIdentifiers, ["c"])
    }

    @MainActor
    func testMergeWithPreviousCombinesAssetsAndRemovesPlace() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let a = make(id: "a", date: start, latitude: 37.56, longitude: 126.97)
        let b = make(id: "b", date: start.addingTimeInterval(3_600), latitude: 37.58, longitude: 126.99)
        let first = makePlace(id: UUID(), title: "A", assets: [a])
        let second = makePlace(id: UUID(), title: "B", assets: [b])
        let draft = makeDraft(assets: [a, b], places: [first, second])

        XCTAssertTrue(draft.mergeWithPrevious(second.id))
        XCTAssertEqual(draft.places.count, 1)
        XCTAssertEqual(Set(draft.places[0].assetIdentifiers), Set(["a", "b"]))
    }

    private func make(
        id: String,
        date: Date,
        latitude: Double,
        longitude: Double,
        isFavorite: Bool = false
    ) -> PhotoAssetSnapshot {
        PhotoAssetSnapshot(
            id: id,
            creationDate: date,
            latitude: latitude,
            longitude: longitude,
            pixelWidth: 4_032,
            pixelHeight: 3_024,
            isFavorite: isFavorite,
            isScreenshot: false
        )
    }

    private func makePlace(id: UUID, title: String, assets: [PhotoAssetSnapshot]) -> BoardPlace {
        BoardPlace(
            id: id,
            title: title,
            subtitle: nil,
            administrativeArea: "서울특별시",
            locality: "서울",
            latitude: assets.map(\.latitude).reduce(0, +) / Double(assets.count),
            longitude: assets.map(\.longitude).reduce(0, +) / Double(assets.count),
            startDate: assets.first?.creationDate ?? .distantPast,
            endDate: assets.last?.creationDate ?? .distantPast,
            assetIdentifiers: assets.map(\.id),
            representativeAssetIdentifier: assets[0].id,
            isHidden: false,
            sourceAssetIdentifiers: assets.map(\.id),
            note: nil
        )
    }

    @MainActor
    private func makeDraft(assets: [PhotoAssetSnapshot], places: [BoardPlace]) -> BoardDraft {
        BoardDraft(
            date: assets.first?.creationDate ?? .now,
            title: "Test",
            places: places,
            mapImage: UIImage.solid(color: .lightGray),
            normalizedPoints: Dictionary(uniqueKeysWithValues: places.map { ($0.id, CGPoint(x: 0.5, y: 0.5)) }),
            photoImages: [:],
            sourceAssets: assets
        )
    }
}
