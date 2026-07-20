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

enum BoardThreadColor: String, CaseIterable, Codable, Identifiable {
    case vermilion, indigo, forest, ochre, charcoal, rose

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vermilion: return "주홍"
        case .indigo: return "남색"
        case .forest: return "숲색"
        case .ochre: return "황토"
        case .charcoal: return "먹색"
        case .rose: return "장미"
        }
    }
    var primaryHex: UInt {
        switch self {
        case .vermilion: return 0xBE3D2C
        case .indigo: return 0x36506E
        case .forest: return 0x3F654F
        case .ochre: return 0xA56B2A
        case .charcoal: return 0x4B4B49
        case .rose: return 0xA64C62
        }
    }
    var highlightHex: UInt {
        switch self {
        case .vermilion: return 0xE8927A
        case .indigo: return 0x8DA6C1
        case .forest: return 0x8FAF98
        case .ochre: return 0xD9A767
        case .charcoal: return 0xA8A8A2
        case .rose: return 0xD895A5
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
    let threadColor: BoardThreadColor
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

@MainActor
@Observable
final class BoardDraft: Identifiable {
    let id: UUID
    let date: Date
    var title: String
    var places: [BoardPlace]
    var template: BoardTemplate
    var threadColor: BoardThreadColor
    var mapImage: UIImage
    var normalizedPoints: [UUID: CGPoint]
    var photoImages: [String: UIImage]

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        places: [BoardPlace],
        template: BoardTemplate = .ribbon,
        threadColor: BoardThreadColor = .vermilion,
        mapImage: UIImage,
        normalizedPoints: [UUID: CGPoint],
        photoImages: [String: UIImage]
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.places = places
        self.template = template
        self.threadColor = threadColor
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
            threadColor: threadColor,
            mapImage: mapImage,
            normalizedPoints: normalizedPoints,
            photoImages: photoImages
        )
    }
}

struct BoardArchivePayload: Codable {
    let date: Date
    let title: String
    let places: [BoardPlace]
    let template: BoardTemplate
    let threadColor: BoardThreadColor?

    init(date: Date, title: String, places: [BoardPlace], template: BoardTemplate, threadColor: BoardThreadColor? = nil) {
        self.date = date
        self.title = title
        self.places = places
        self.template = template
        self.threadColor = threadColor
    }
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
