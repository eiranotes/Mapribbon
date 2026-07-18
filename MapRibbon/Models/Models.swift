import Foundation
import CoreLocation
import Photos
import SwiftData
import UIKit
import Observation

struct PhotoAssetSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let creationDate: Date
    let latitude: Double
    let longitude: Double
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isScreenshot: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var pixelArea: Int {
        pixelWidth * pixelHeight
    }
}

struct PhotoDaySummary: Identifiable, Hashable, Sendable {
    let date: Date
    let assets: [PhotoAssetSnapshot]

    var id: Date { date }
    var photoCount: Int { assets.count }
    var thumbnailIdentifier: String? { assets.first?.id }

    var estimatedPlaceCount: Int {
        max(1, min(8, PhotoClusterer.cluster(assets).count))
    }
}

struct PlaceName: Hashable, Sendable {
    let title: String
    let subtitle: String?
    let administrativeArea: String?
    let locality: String?
}

struct BoardPlace: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var subtitle: String?
    var administrativeArea: String?
    var locality: String?
    var latitude: Double
    var longitude: Double
    var startDate: Date
    var endDate: Date
    var assetIdentifiers: [String]
    var representativeAssetIdentifier: String
    var isHidden: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var photoCount: Int { assetIdentifiers.count }
}

enum BoardTemplate: String, CaseIterable, Codable, Identifiable {
    case ribbon
    case editorial
    case postcard
    case scrapbook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ribbon: return "리본"
        case .editorial: return "에디토리얼"
        case .postcard: return "포스트카드"
        case .scrapbook: return "스크랩"
        }
    }

    var symbolName: String {
        switch self {
        case .ribbon: return "point.topleft.down.to.point.bottomright.curvepath"
        case .editorial: return "rectangle.split.2x1"
        case .postcard: return "postcard"
        case .scrapbook: return "square.stack.3d.up"
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case story
    case feed
    case poster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .story: return "스토리 9:16"
        case .feed: return "피드 4:5"
        case .poster: return "포스터 3:4"
        }
    }

    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .feed: return CGSize(width: 1080, height: 1350)
        case .poster: return CGSize(width: 1080, height: 1440)
        }
    }

    var aspectRatio: CGFloat {
        size.width / size.height
    }

    static func resolved(from rawValue: String?) -> ExportFormat {
        rawValue.flatMap(ExportFormat.init(rawValue:)) ?? .story
    }
}

enum GenerationStep: String, CaseIterable, Identifiable {
    case readingPhotos
    case groupingPlaces
    case namingPlaces
    case preparingMap
    case composingBoard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readingPhotos: return "사진 불러오는 중"
        case .groupingPlaces: return "장소를 묶는 중"
        case .namingPlaces: return "장소 이름 찾는 중"
        case .preparingMap: return "지도를 준비하는 중"
        case .composingBoard: return "보드를 구성하는 중"
        }
    }
}

struct BoardRenderModel {
    let id: UUID
    let title: String
    let date: Date
    let places: [BoardPlace]
    let template: BoardTemplate
    let mapImage: UIImage
    let normalizedPoints: [UUID: CGPoint]
    let photoImages: [String: UIImage]

    var visiblePlaces: [BoardPlace] {
        places.filter { !$0.isHidden }
    }

    var photoCount: Int {
        places.reduce(0) { $0 + $1.photoCount }
    }
}

struct ImportedBoardPhoto {
    let identifier: String
    let image: UIImage
}

struct BoardThreadSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
}

enum BoardLayout {
    private static let tallCenters: [CGPoint] = [
        CGPoint(x: 0.25, y: 0.34), CGPoint(x: 0.73, y: 0.42),
        CGPoint(x: 0.29, y: 0.59), CGPoint(x: 0.70, y: 0.69),
        CGPoint(x: 0.29, y: 0.81), CGPoint(x: 0.72, y: 0.86),
        CGPoint(x: 0.51, y: 0.50), CGPoint(x: 0.50, y: 0.76)
    ]

    private static let compactCenters: [CGPoint] = [
        CGPoint(x: 0.20, y: 0.38), CGPoint(x: 0.50, y: 0.36), CGPoint(x: 0.79, y: 0.40),
        CGPoint(x: 0.27, y: 0.70), CGPoint(x: 0.60, y: 0.68), CGPoint(x: 0.82, y: 0.73),
        CGPoint(x: 0.44, y: 0.53), CGPoint(x: 0.68, y: 0.54)
    ]

    static func isTall(aspectRatio: CGFloat) -> Bool {
        aspectRatio < 0.68
    }

    static func cardCenters(count: Int, aspectRatio: CGFloat) -> [CGPoint] {
        let source = isTall(aspectRatio: aspectRatio) ? tallCenters : compactCenters
        return Array(source.prefix(max(0, min(count, source.count))))
    }

    static func pinPoints(count: Int, aspectRatio: CGFloat) -> [CGPoint] {
        let offset: CGFloat = isTall(aspectRatio: aspectRatio) ? 0.092 : 0.105
        return cardCenters(count: count, aspectRatio: aspectRatio).map {
            CGPoint(x: $0.x, y: max(0.20, $0.y - offset))
        }
    }

    static func threadSegments(count: Int, aspectRatio: CGFloat) -> [BoardThreadSegment] {
        let points = pinPoints(count: count, aspectRatio: aspectRatio)
        guard points.count > 1 else { return [] }
        return zip(points, points.dropFirst()).map { BoardThreadSegment(start: $0.0, end: $0.1) }
    }

    static func insertionPoint(index: Int) -> CGPoint {
        tallCenters[index % tallCenters.count]
    }
}

@MainActor
@Observable
final class BoardDraft: Identifiable {
    let id: UUID
    let date: Date
    var title: String
    var places: [BoardPlace]
    var template: BoardTemplate
    var mapImage: UIImage
    var normalizedPoints: [UUID: CGPoint]
    var photoImages: [String: UIImage]

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        places: [BoardPlace],
        template: BoardTemplate = .ribbon,
        mapImage: UIImage,
        normalizedPoints: [UUID: CGPoint],
        photoImages: [String: UIImage]
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.places = places
        self.template = template
        self.mapImage = mapImage
        self.normalizedPoints = normalizedPoints
        self.photoImages = photoImages
    }

    var renderModel: BoardRenderModel {
        BoardRenderModel(
            id: id,
            title: title,
            date: date,
            places: places,
            template: template,
            mapImage: mapImage,
            normalizedPoints: normalizedPoints,
            photoImages: photoImages
        )
    }

    var archivePayload: BoardArchivePayload {
        BoardArchivePayload(date: date, title: title, places: places, template: template)
    }

    var fingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return (try? encoder.encode(archivePayload).base64EncodedString()) ?? ""
    }

    @discardableResult
    func appendManualPlace(
        title: String,
        subtitle: String?,
        startDate: Date,
        endDate: Date
    ) -> UUID {
        let identifier = UUID()
        let center = averageCoordinate
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = BoardPlace(
            id: identifier,
            title: trimmedTitle.isEmpty ? "새 장소" : trimmedTitle,
            subtitle: subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            administrativeArea: nil,
            locality: nil,
            latitude: center.latitude,
            longitude: center.longitude,
            startDate: min(startDate, endDate),
            endDate: max(startDate, endDate),
            assetIdentifiers: [],
            representativeAssetIdentifier: "",
            isHidden: false
        )
        places.append(place)
        normalizedPoints[identifier] = BoardLayout.insertionPoint(index: places.count - 1)
        return identifier
    }

    @discardableResult
    func appendImportedPhotos(_ photos: [ImportedBoardPhoto], to placeID: UUID? = nil) -> UUID? {
        guard !photos.isEmpty else { return nil }
        for photo in photos {
            photoImages[photo.identifier] = photo.image
        }

        if let placeID, let index = places.firstIndex(where: { $0.id == placeID }) {
            let identifiers = photos.map(\.identifier)
            places[index].assetIdentifiers.append(contentsOf: identifiers)
            if places[index].representativeAssetIdentifier.isEmpty {
                places[index].representativeAssetIdentifier = identifiers[0]
            }
            return placeID
        }

        let center = averageCoordinate
        let identifier = UUID()
        let importedIdentifiers = photos.map(\.identifier)
        let place = BoardPlace(
            id: identifier,
            title: "추가한 사진",
            subtitle: "직접 선택한 사진",
            administrativeArea: nil,
            locality: nil,
            latitude: center.latitude,
            longitude: center.longitude,
            startDate: date,
            endDate: date,
            assetIdentifiers: importedIdentifiers,
            representativeAssetIdentifier: importedIdentifiers[0],
            isHidden: false
        )
        places.append(place)
        normalizedPoints[identifier] = BoardLayout.insertionPoint(index: places.count - 1)
        return identifier
    }

    func removePhoto(identifier: String, from placeID: UUID) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].assetIdentifiers.removeAll { $0 == identifier }
        photoImages.removeValue(forKey: identifier)
        if places[index].representativeAssetIdentifier == identifier {
            places[index].representativeAssetIdentifier = places[index].assetIdentifiers.first ?? ""
        }
    }

    func deletePlace(id: UUID) {
        guard let place = places.first(where: { $0.id == id }) else { return }
        places.removeAll { $0.id == id }
        normalizedPoints.removeValue(forKey: id)
        let remainingIdentifiers = Set(places.flatMap(\.assetIdentifiers))
        for identifier in place.assetIdentifiers where !remainingIdentifiers.contains(identifier) {
            photoImages.removeValue(forKey: identifier)
        }
    }

    @discardableResult
    func mergePlace(sourceID: UUID, into targetID: UUID) -> Bool {
        guard sourceID != targetID,
              let sourceIndex = places.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = places.firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        let source = places[sourceIndex]
        var target = places[targetIndex]
        let existing = Set(target.assetIdentifiers)
        target.assetIdentifiers.append(contentsOf: source.assetIdentifiers.filter { !existing.contains($0) })
        if target.representativeAssetIdentifier.isEmpty {
            target.representativeAssetIdentifier = source.representativeAssetIdentifier
        }
        target.startDate = min(target.startDate, source.startDate)
        target.endDate = max(target.endDate, source.endDate)
        if target.subtitle == nil { target.subtitle = source.subtitle }
        places[targetIndex] = target
        places.remove(at: sourceIndex)
        normalizedPoints.removeValue(forKey: sourceID)
        return true
    }

    func reorderPlaces(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { places[$0] }
        for index in source.sorted(by: >) {
            places.remove(at: index)
        }
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertion = max(0, min(places.count, destination - removedBeforeDestination))
        places.insert(contentsOf: moving, at: insertion)
    }

    private var averageCoordinate: CLLocationCoordinate2D {
        guard !places.isEmpty else {
            return CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        }
        let latitude = places.reduce(0) { $0 + $1.latitude } / Double(places.count)
        let longitude = places.reduce(0) { $0 + $1.longitude } / Double(places.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct BoardArchivePayload: Codable {
    let date: Date
    let title: String
    let places: [BoardPlace]
    let template: BoardTemplate
}

@Model
final class SavedBoard {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date
    var title: String
    var photoCount: Int
    var placeCount: Int
    var templateRawValue: String
    @Attribute(.externalStorage) var previewImageData: Data
    @Attribute(.externalStorage) var payloadData: Data
    var regionKeysJSON: String

    init(
        id: UUID = UUID(),
        date: Date,
        createdAt: Date = .now,
        title: String,
        photoCount: Int,
        placeCount: Int,
        templateRawValue: String,
        previewImageData: Data,
        payloadData: Data,
        regionKeysJSON: String
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.title = title
        self.photoCount = photoCount
        self.placeCount = placeCount
        self.templateRawValue = templateRawValue
        self.previewImageData = previewImageData
        self.payloadData = payloadData
        self.regionKeysJSON = regionKeysJSON
    }

    var template: BoardTemplate {
        BoardTemplate(rawValue: templateRawValue) ?? .ribbon
    }

    var regionKeys: [String] {
        guard let data = regionKeysJSON.data(using: .utf8),
              let keys = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return keys
    }
}

struct KoreaRegion: Identifiable, Hashable {
    let key: String
    let displayName: String
    let shortName: String
    let normalizedPoint: CGPoint

    var id: String { key }

    static let all: [KoreaRegion] = [
        .init(key: "서울", displayName: "서울특별시", shortName: "서울", normalizedPoint: CGPoint(x: 0.43, y: 0.20)),
        .init(key: "부산", displayName: "부산광역시", shortName: "부산", normalizedPoint: CGPoint(x: 0.76, y: 0.78)),
        .init(key: "대구", displayName: "대구광역시", shortName: "대구", normalizedPoint: CGPoint(x: 0.66, y: 0.61)),
        .init(key: "인천", displayName: "인천광역시", shortName: "인천", normalizedPoint: CGPoint(x: 0.31, y: 0.22)),
        .init(key: "광주", displayName: "광주광역시", shortName: "광주", normalizedPoint: CGPoint(x: 0.40, y: 0.72)),
        .init(key: "대전", displayName: "대전광역시", shortName: "대전", normalizedPoint: CGPoint(x: 0.50, y: 0.47)),
        .init(key: "울산", displayName: "울산광역시", shortName: "울산", normalizedPoint: CGPoint(x: 0.78, y: 0.68)),
        .init(key: "세종", displayName: "세종특별자치시", shortName: "세종", normalizedPoint: CGPoint(x: 0.46, y: 0.41)),
        .init(key: "경기", displayName: "경기도", shortName: "경기", normalizedPoint: CGPoint(x: 0.45, y: 0.27)),
        .init(key: "강원", displayName: "강원특별자치도", shortName: "강원", normalizedPoint: CGPoint(x: 0.69, y: 0.24)),
        .init(key: "충북", displayName: "충청북도", shortName: "충북", normalizedPoint: CGPoint(x: 0.56, y: 0.42)),
        .init(key: "충남", displayName: "충청남도", shortName: "충남", normalizedPoint: CGPoint(x: 0.36, y: 0.46)),
        .init(key: "전북", displayName: "전북특별자치도", shortName: "전북", normalizedPoint: CGPoint(x: 0.43, y: 0.59)),
        .init(key: "전남", displayName: "전라남도", shortName: "전남", normalizedPoint: CGPoint(x: 0.37, y: 0.79)),
        .init(key: "경북", displayName: "경상북도", shortName: "경북", normalizedPoint: CGPoint(x: 0.69, y: 0.49)),
        .init(key: "경남", displayName: "경상남도", shortName: "경남", normalizedPoint: CGPoint(x: 0.62, y: 0.72)),
        .init(key: "제주", displayName: "제주특별자치도", shortName: "제주", normalizedPoint: CGPoint(x: 0.42, y: 0.96))
    ]
}
