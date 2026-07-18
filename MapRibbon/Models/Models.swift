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

    func filtering(to identifiers: Set<String>) -> PhotoDaySummary {
        PhotoDaySummary(
            date: date,
            assets: assets.filter { identifiers.contains($0.id) }
        )
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
    var sourceAssetIdentifiers: [String]?
    var note: String?

    init(
        id: UUID,
        title: String,
        subtitle: String?,
        administrativeArea: String?,
        locality: String?,
        latitude: Double,
        longitude: Double,
        startDate: Date,
        endDate: Date,
        assetIdentifiers: [String],
        representativeAssetIdentifier: String,
        isHidden: Bool,
        sourceAssetIdentifiers: [String]? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.administrativeArea = administrativeArea
        self.locality = locality
        self.latitude = latitude
        self.longitude = longitude
        self.startDate = startDate
        self.endDate = endDate
        self.assetIdentifiers = assetIdentifiers
        self.representativeAssetIdentifier = representativeAssetIdentifier
        self.isHidden = isHidden
        self.sourceAssetIdentifiers = sourceAssetIdentifiers
        self.note = note
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var photoCount: Int { assetIdentifiers.count }
    var availableAssetIdentifiers: [String] { sourceAssetIdentifiers ?? assetIdentifiers }

    var timeRangeText: String {
        let start = startDate.formatted(date: .omitted, time: .shortened)
        let end = endDate.formatted(date: .omitted, time: .shortened)
        return start == end ? start : "\(start)–\(end)"
    }
}

enum BoardTemplate: String, CaseIterable, Codable, Identifiable {
    case pinboard
    case ribbon
    case editorial
    case postcard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinboard: return "핀보드"
        case .ribbon: return "리본"
        case .editorial: return "에디토리얼"
        case .postcard: return "포스트카드"
        }
    }

    var symbolName: String {
        switch self {
        case .pinboard: return "pin.fill"
        case .ribbon: return "point.topleft.down.to.point.bottomright.curvepath"
        case .editorial: return "rectangle.split.2x1"
        case .postcard: return "postcard"
        }
    }
}

enum PhotoSelectionMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "자동 선택"
        case .manual: return "직접 선택"
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
        case .composingBoard: return "핀보드를 구성하는 중"
        }
    }
}

struct BoardRenderModel {
    let id: UUID
    let title: String
    let caption: String
    let date: Date
    let places: [BoardPlace]
    let template: BoardTemplate
    let mapImage: UIImage
    let normalizedPoints: [UUID: CGPoint]
    let photoImages: [String: UIImage]

    var visiblePlaces: [BoardPlace] {
        places.filter { !$0.isHidden && !$0.assetIdentifiers.isEmpty }
    }

    var photoCount: Int {
        visiblePlaces.reduce(0) { $0 + $1.photoCount }
    }
}

@MainActor
@Observable
final class BoardDraft: Identifiable {
    let id: UUID
    let date: Date
    var title: String
    var caption: String
    var places: [BoardPlace]
    var template: BoardTemplate
    var mapImage: UIImage
    var normalizedPoints: [UUID: CGPoint]
    var photoImages: [String: UIImage]
    var sourceAssets: [PhotoAssetSnapshot]

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        caption: String = "",
        places: [BoardPlace],
        template: BoardTemplate = .pinboard,
        mapImage: UIImage,
        normalizedPoints: [UUID: CGPoint],
        photoImages: [String: UIImage],
        sourceAssets: [PhotoAssetSnapshot] = []
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.caption = caption
        self.places = places
        self.template = template
        self.mapImage = mapImage
        self.normalizedPoints = normalizedPoints
        self.photoImages = photoImages
        self.sourceAssets = sourceAssets
    }

    var renderModel: BoardRenderModel {
        BoardRenderModel(
            id: id,
            title: title,
            caption: caption,
            date: date,
            places: places,
            template: template,
            mapImage: mapImage,
            normalizedPoints: normalizedPoints,
            photoImages: photoImages
        )
    }

    var allSourceIdentifiers: [String] { sourceAssets.map(\.id) }
    var assignedIdentifiers: Set<String> { Set(places.flatMap(\.assetIdentifiers)) }
    var unassignedIdentifiers: [String] { allSourceIdentifiers.filter { !assignedIdentifiers.contains($0) } }

    func asset(for identifier: String) -> PhotoAssetSnapshot? {
        sourceAssets.first { $0.id == identifier }
    }

    func ownerID(of identifier: String) -> UUID? {
        places.first(where: { $0.assetIdentifiers.contains(identifier) })?.id
    }

    func toggleAsset(_ identifier: String, for placeID: UUID) {
        guard let targetIndex = places.firstIndex(where: { $0.id == placeID }) else { return }

        if places[targetIndex].assetIdentifiers.contains(identifier) {
            guard places[targetIndex].assetIdentifiers.count > 1 else { return }
            places[targetIndex].assetIdentifiers.removeAll { $0 == identifier }
            if places[targetIndex].representativeAssetIdentifier == identifier,
               let replacement = places[targetIndex].assetIdentifiers.first {
                places[targetIndex].representativeAssetIdentifier = replacement
            }
            refreshDates(for: targetIndex)
            return
        }

        for index in places.indices where index != targetIndex {
            places[index].assetIdentifiers.removeAll { $0 == identifier }
            if places[index].representativeAssetIdentifier == identifier,
               let replacement = places[index].assetIdentifiers.first {
                places[index].representativeAssetIdentifier = replacement
            }
            refreshDates(for: index)
        }

        places[targetIndex].assetIdentifiers.append(identifier)
        places[targetIndex].assetIdentifiers.sort {
            (asset(for: $0)?.creationDate ?? .distantPast) < (asset(for: $1)?.creationDate ?? .distantPast)
        }
        refreshDates(for: targetIndex)
    }

    func splitPlace(_ placeID: UUID) -> Bool {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return false }
        let identifiers = places[index].assetIdentifiers.sorted {
            (asset(for: $0)?.creationDate ?? .distantPast) < (asset(for: $1)?.creationDate ?? .distantPast)
        }
        guard identifiers.count >= 2 else { return false }

        var splitIndex: Int?
        var largestGap: TimeInterval = 0
        for position in 1..<identifiers.count {
            guard let previous = asset(for: identifiers[position - 1]),
                  let current = asset(for: identifiers[position]) else { continue }
            let gap = current.creationDate.timeIntervalSince(previous.creationDate)
            if gap > largestGap {
                largestGap = gap
                splitIndex = position
            }
        }

        guard let splitIndex, largestGap >= 45 * 60 else { return false }
        let firstIDs = Array(identifiers[..<splitIndex])
        let secondIDs = Array(identifiers[splitIndex...])
        guard let secondFirst = secondIDs.first,
              let secondRepresentative = asset(for: secondFirst) else { return false }

        places[index].assetIdentifiers = firstIDs
        places[index].representativeAssetIdentifier = firstIDs.first ?? places[index].representativeAssetIdentifier
        refreshDates(for: index)

        var newPlace = places[index]
        newPlace.id = UUID()
        newPlace.assetIdentifiers = secondIDs
        newPlace.sourceAssetIdentifiers = Array(Set(newPlace.availableAssetIdentifiers + secondIDs))
        newPlace.representativeAssetIdentifier = secondRepresentative.id
        newPlace.startDate = secondRepresentative.creationDate
        newPlace.endDate = asset(for: secondIDs.last ?? secondFirst)?.creationDate ?? secondRepresentative.creationDate
        newPlace.note = "재방문"
        places.insert(newPlace, at: min(index + 1, places.endIndex))
        normalizedPoints[newPlace.id] = normalizedPoints[placeID]
        return true
    }

    func mergeWithPrevious(_ placeID: UUID) -> Bool {
        guard let index = places.firstIndex(where: { $0.id == placeID }), index > 0 else { return false }
        var previous = places[index - 1]
        let current = places[index]
        previous.assetIdentifiers = Array(Set(previous.assetIdentifiers + current.assetIdentifiers)).sorted {
            (asset(for: $0)?.creationDate ?? .distantPast) < (asset(for: $1)?.creationDate ?? .distantPast)
        }
        previous.sourceAssetIdentifiers = Array(Set(previous.availableAssetIdentifiers + current.availableAssetIdentifiers))
        previous.endDate = max(previous.endDate, current.endDate)
        if !previous.assetIdentifiers.isEmpty,
           !previous.assetIdentifiers.contains(previous.representativeAssetIdentifier) {
            previous.representativeAssetIdentifier = previous.assetIdentifiers[0]
        }
        places[index - 1] = previous
        places.remove(at: index)
        normalizedPoints.removeValue(forKey: current.id)
        return true
    }

    func isRepeatedLocation(at index: Int) -> Bool {
        guard places.indices.contains(index) else { return false }
        let location = CLLocation(latitude: places[index].latitude, longitude: places[index].longitude)
        for otherIndex in places.indices where otherIndex != index {
            let other = CLLocation(latitude: places[otherIndex].latitude, longitude: places[otherIndex].longitude)
            if location.distance(from: other) < 180 { return true }
        }
        return false
    }

    private func refreshDates(for index: Int) {
        guard places.indices.contains(index) else { return }
        let dates = places[index].assetIdentifiers.compactMap { asset(for: $0)?.creationDate }.sorted()
        if let first = dates.first { places[index].startDate = first }
        if let last = dates.last { places[index].endDate = last }
    }
}

struct BoardArchivePayload: Codable {
    let date: Date
    let title: String
    let caption: String?
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

    var template: BoardTemplate { BoardTemplate(rawValue: templateRawValue) ?? .pinboard }

    var regionKeys: [String] {
        guard let data = regionKeysJSON.data(using: .utf8),
              let keys = try? JSONDecoder().decode([String].self, from: data) else { return [] }
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
