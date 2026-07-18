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

@MainActor
final class BoardDraftMutationTests: XCTestCase {
    func testManualPlaceAddsStablePointAndNormalizesDates() {
        let draft = makeDraft()
        let later = Date(timeIntervalSince1970: 2_000)
        let earlier = Date(timeIntervalSince1970: 1_000)

        let id = draft.appendManualPlace(
            title: "  새 장소  ",
            subtitle: "  메모  ",
            startDate: later,
            endDate: earlier
        )

        let place = try? XCTUnwrap(draft.places.first(where: { $0.id == id }))
        XCTAssertEqual(place?.title, "새 장소")
        XCTAssertEqual(place?.subtitle, "메모")
        XCTAssertEqual(place?.startDate, earlier)
        XCTAssertEqual(place?.endDate, later)
        XCTAssertEqual(draft.normalizedPoints[id], BoardLayout.insertionPoint(index: 2))
    }

    func testImportedPhotosAppendToTargetAndSetRepresentative() {
        let draft = makeDraft(emptyFirstPlace: true)
        let targetID = draft.places[0].id
        let photos = [
            ImportedBoardPhoto(identifier: "new-a", image: UIImage.solid(color: .black)),
            ImportedBoardPhoto(identifier: "new-b", image: UIImage.solid(color: .white))
        ]

        let result = draft.appendImportedPhotos(photos, to: targetID)

        XCTAssertEqual(result, targetID)
        XCTAssertEqual(draft.places[0].assetIdentifiers, ["new-a", "new-b"])
        XCTAssertEqual(draft.places[0].representativeAssetIdentifier, "new-a")
        XCTAssertNotNil(draft.photoImages["new-a"])
    }

    func testRemovingRepresentativePhotoSelectsNextPhoto() {
        let draft = makeDraft()
        let placeID = draft.places[0].id

        draft.removePhoto(identifier: "a", from: placeID)

        XCTAssertEqual(draft.places[0].assetIdentifiers, ["b"])
        XCTAssertEqual(draft.places[0].representativeAssetIdentifier, "b")
        XCTAssertNil(draft.photoImages["a"])
    }

    func testMergeCombinesUniquePhotosAndTimeRange() {
        let draft = makeDraft()
        let sourceID = draft.places[0].id
        let targetID = draft.places[1].id
        let sourceStart = draft.places[0].startDate
        let targetEnd = draft.places[1].endDate

        XCTAssertTrue(draft.mergePlace(sourceID: sourceID, into: targetID))

        XCTAssertEqual(draft.places.count, 1)
        XCTAssertEqual(draft.places[0].id, targetID)
        XCTAssertEqual(draft.places[0].assetIdentifiers, ["c", "a", "b"])
        XCTAssertEqual(draft.places[0].startDate, sourceStart)
        XCTAssertEqual(draft.places[0].endDate, targetEnd)
        XCTAssertNil(draft.normalizedPoints[sourceID])
    }

    func testReorderPlacesChangesBoardSequence() {
        let draft = makeDraft()
        let originalFirst = draft.places[0].id

        draft.reorderPlaces(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(draft.places.last?.id, originalFirst)
    }

    func testFingerprintDetectsUnsavedMutation() {
        let draft = makeDraft()
        let initial = draft.fingerprint

        draft.title = "수정된 제목"

        XCTAssertNotEqual(draft.fingerprint, initial)
    }

    func testStraightThreadSegmentsJoinAdjacentPins() {
        let pins = BoardLayout.pinPoints(count: 4, aspectRatio: 9.0 / 16.0)
        let segments = BoardLayout.threadSegments(count: 4, aspectRatio: 9.0 / 16.0)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0], BoardThreadSegment(start: pins[0], end: pins[1]))
        XCTAssertEqual(segments[1], BoardThreadSegment(start: pins[1], end: pins[2]))
        XCTAssertEqual(segments[2], BoardThreadSegment(start: pins[2], end: pins[3]))
    }

    func testExportFormatUsesStoredValueAndFallsBackToStory() {
        XCTAssertEqual(ExportFormat.resolved(from: "feed"), .feed)
        XCTAssertEqual(ExportFormat.resolved(from: "unknown"), .story)
        XCTAssertEqual(ExportFormat.resolved(from: nil), .story)
    }

    private func makeDraft(emptyFirstPlace: Bool = false) -> BoardDraft {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let firstAssets = emptyFirstPlace ? [] : ["a", "b"]
        let firstRepresentative = emptyFirstPlace ? "" : "a"
        let places = [
            BoardPlace(
                id: firstID,
                title: "첫 장소",
                subtitle: "첫 설명",
                administrativeArea: "서울특별시",
                locality: "종로구",
                latitude: 37.57,
                longitude: 126.98,
                startDate: start,
                endDate: start.addingTimeInterval(1_800),
                assetIdentifiers: firstAssets,
                representativeAssetIdentifier: firstRepresentative,
                isHidden: false
            ),
            BoardPlace(
                id: secondID,
                title: "둘째 장소",
                subtitle: nil,
                administrativeArea: "서울특별시",
                locality: "중구",
                latitude: 37.56,
                longitude: 126.99,
                startDate: start.addingTimeInterval(3_600),
                endDate: start.addingTimeInterval(5_400),
                assetIdentifiers: ["c"],
                representativeAssetIdentifier: "c",
                isHidden: false
            )
        ]
        let image = UIImage.solid(color: .gray)
        return BoardDraft(
            date: start,
            title: "테스트 보드",
            places: places,
            mapImage: image,
            normalizedPoints: [
                firstID: CGPoint(x: 0.2, y: 0.3),
                secondID: CGPoint(x: 0.7, y: 0.6)
            ],
            photoImages: ["a": image, "b": image, "c": image]
        )
    }
}
