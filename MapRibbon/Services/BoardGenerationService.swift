import Foundation
import CoreLocation
import MapKit
import UIKit

struct PhotoClusterer {
    struct Cluster: Identifiable, Hashable, Sendable {
        let id: UUID
        var assets: [PhotoAssetSnapshot]
        var latitude: Double
        var longitude: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var startDate: Date {
            assets.first?.creationDate ?? .distantPast
        }

        var endDate: Date {
            assets.last?.creationDate ?? .distantPast
        }

        mutating func append(_ asset: PhotoAssetSnapshot) {
            assets.append(asset)
            recalculateCentroid()
        }

        mutating func absorb(_ other: Cluster) {
            assets.append(contentsOf: other.assets)
            assets.sort { $0.creationDate < $1.creationDate }
            recalculateCentroid()
        }

        mutating private func recalculateCentroid() {
            guard !assets.isEmpty else { return }
            latitude = assets.map(\.latitude).reduce(0, +) / Double(assets.count)
            longitude = assets.map(\.longitude).reduce(0, +) / Double(assets.count)
        }
    }

    static func cluster(
        _ input: [PhotoAssetSnapshot],
        distanceThreshold: CLLocationDistance = 420,
        timeGap: TimeInterval = 2.5 * 60 * 60,
        maxClusters: Int = 8
    ) -> [Cluster] {
        let assets = input
            .filter { !$0.isScreenshot }
            .sorted { $0.creationDate < $1.creationDate }

        guard let first = assets.first else { return [] }

        var clusters: [Cluster] = [
            Cluster(
                id: UUID(),
                assets: [first],
                latitude: first.latitude,
                longitude: first.longitude
            )
        ]

        for asset in assets.dropFirst() {
            guard var current = clusters.popLast() else { continue }
            let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
                .distance(from: CLLocation(latitude: asset.latitude, longitude: asset.longitude))
            let gap = asset.creationDate.timeIntervalSince(current.endDate)

            if distance <= distanceThreshold && gap <= timeGap {
                current.append(asset)
                clusters.append(current)
            } else {
                clusters.append(current)
                clusters.append(
                    Cluster(
                        id: UUID(),
                        assets: [asset],
                        latitude: asset.latitude,
                        longitude: asset.longitude
                    )
                )
            }
        }

        clusters = mergeAdjacentNearby(clusters)

        while clusters.count > maxClusters {
            guard let pairIndex = nearestAdjacentPair(in: clusters) else { break }
            var left = clusters[pairIndex]
            left.absorb(clusters[pairIndex + 1])
            clusters.replaceSubrange(pairIndex...(pairIndex + 1), with: [left])
        }

        return clusters
    }

    private static func mergeAdjacentNearby(_ source: [Cluster]) -> [Cluster] {
        guard !source.isEmpty else { return [] }
        var output: [Cluster] = []

        for cluster in source {
            guard var previous = output.popLast() else {
                output.append(cluster)
                continue
            }

            let distance = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: cluster.latitude, longitude: cluster.longitude))
            let gap = cluster.startDate.timeIntervalSince(previous.endDate)

            if distance <= 190 && gap <= 5 * 60 * 60 {
                previous.absorb(cluster)
                output.append(previous)
            } else {
                output.append(previous)
                output.append(cluster)
            }
        }

        return output
    }

    private static func nearestAdjacentPair(in clusters: [Cluster]) -> Int? {
        guard clusters.count >= 2 else { return nil }
        var result: (index: Int, score: Double)?

        for index in 0..<(clusters.count - 1) {
            let left = clusters[index]
            let right = clusters[index + 1]
            let distance = CLLocation(latitude: left.latitude, longitude: left.longitude)
                .distance(from: CLLocation(latitude: right.latitude, longitude: right.longitude))
            let time = right.startDate.timeIntervalSince(left.endDate)
            let score = distance + max(0, time / 60)
            if result == nil || score < result!.score {
                result = (index, score)
            }
        }

        return result?.index
    }

    static func representative(in assets: [PhotoAssetSnapshot]) -> PhotoAssetSnapshot? {
        guard !assets.isEmpty else { return nil }
        let medianTime = assets[assets.count / 2].creationDate

        return assets.max { lhs, rhs in
            representativeScore(lhs, medianTime: medianTime) < representativeScore(rhs, medianTime: medianTime)
        }
    }

    private static func representativeScore(_ asset: PhotoAssetSnapshot, medianTime: Date) -> Double {
        let favorite = asset.isFavorite ? 30.0 : 0
        let resolution = min(12.0, log10(Double(max(1, asset.pixelArea))))
        let timePenalty = min(6.0, abs(asset.creationDate.timeIntervalSince(medianTime)) / 3_600)
        let screenshotPenalty = asset.isScreenshot ? 100.0 : 0
        return favorite + resolution - timePenalty - screenshotPenalty
    }
}

struct MapSnapshotResult {
    let image: UIImage
    let normalizedPoints: [UUID: CGPoint]
}

@MainActor
final class MapSnapshotService {
    func snapshot(for places: [BoardPlace], size: CGSize) async throws -> MapSnapshotResult {
        let coordinates = places.map(\.coordinate)
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.scale = 2
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        options.pointOfInterestFilter = .excludingAll

        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        options.preferredConfiguration = configuration
        options.region = Self.region(for: coordinates)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot: MKMapSnapshotter.Snapshot = try await withCheckedThrowingContinuation { continuation in
            snapshotter.start(with: .global(qos: .userInitiated)) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: BoardGenerationError.mapUnavailable)
                }
            }
        }

        var points: [UUID: CGPoint] = [:]
        for place in places {
            let point = snapshot.point(for: place.coordinate)
            points[place.id] = CGPoint(
                x: min(1, max(0, point.x / size.width)),
                y: min(1, max(0, point.y / size.height))
            )
        }

        return MapSnapshotResult(image: snapshot.image, normalizedPoints: points)
    }

    private static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.8),
                span: MKCoordinateSpan(latitudeDelta: 4.8, longitudeDelta: 5.2)
            )
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latitudeDelta = max(0.030, (maxLat - minLat) * 1.45)
        let longitudeDelta = max(0.036, (maxLon - minLon) * 1.45)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

@MainActor
final class BoardGenerationService {
    private let mapService = MapSnapshotService()
    private let imageService = PhotoImageService.shared

    func generate(
        from summary: PhotoDaySummary,
        progress: @escaping @MainActor (GenerationStep, Double) -> Void
    ) async throws -> BoardDraft {
        progress(.readingPhotos, 0.10)
        try Task.checkCancellation()

        let clusters = PhotoClusterer.cluster(summary.assets)
        guard !clusters.isEmpty else {
            throw BoardGenerationError.notEnoughLocatedPhotos
        }

        progress(.groupingPlaces, 0.28)
        try Task.checkCancellation()

        var places: [BoardPlace] = []
        for (index, cluster) in clusters.enumerated() {
            let representative = PhotoClusterer.representative(in: cluster.assets) ?? cluster.assets[0]
            let placeName = await reverseGeocode(cluster.coordinate, fallbackIndex: index)
            places.append(
                BoardPlace(
                    id: cluster.id,
                    title: placeName.title,
                    subtitle: nil,
                    caption: nil,
                    addressSummary: placeName.subtitle,
                    administrativeArea: placeName.administrativeArea,
                    locality: placeName.locality,
                    latitude: cluster.latitude,
                    longitude: cluster.longitude,
                    startDate: cluster.startDate,
                    endDate: cluster.endDate,
                    assetIdentifiers: cluster.assets.map(\.id),
                    representativeAssetIdentifier: representative.id,
                    isHidden: false
                )
            )
            progress(.namingPlaces, 0.30 + (Double(index + 1) / Double(max(1, clusters.count))) * 0.22)
        }

        try Task.checkCancellation()
        progress(.preparingMap, 0.58)
        let mapResult = try await mapService.snapshot(for: places, size: CGSize(width: 900, height: 1200))

        var images: [String: UIImage] = [:]
        for (index, place) in places.enumerated() {
            if let image = await imageService.image(
                for: place.representativeAssetIdentifier,
                targetSize: CGSize(width: 760, height: 760),
                highQuality: true
            ) {
                images[place.representativeAssetIdentifier] = image
            }
            progress(.composingBoard, 0.66 + (Double(index + 1) / Double(max(1, places.count))) * 0.30)
        }

        let primaryLocality = places
            .compactMap { $0.locality ?? $0.administrativeArea }
            .first
        let title = primaryLocality.map { "\($0) 하루 여행" } ?? "하루 여행"

        progress(.composingBoard, 1.0)
        return BoardDraft(
            date: summary.date,
            title: title,
            places: places,
            template: .ribbon,
            mapImage: mapResult.image,
            normalizedPoints: mapResult.normalizedPoints,
            photoImages: images
        )
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D, fallbackIndex: Int) async -> PlaceName {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                preferredLocale: Locale.autoupdatingCurrent
            )
            guard let placemark = placemarks.first else {
                return fallbackName(fallbackIndex)
            }

            let title = placemark.subLocality
                ?? placemark.name
                ?? placemark.locality
                ?? "장소 \(fallbackIndex + 1)"
            let subtitle = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }
                .filter { $0 != title }
                .prefix(2)
                .joined(separator: " · ")

            return PlaceName(
                title: title,
                subtitle: subtitle.isEmpty ? nil : subtitle,
                administrativeArea: placemark.administrativeArea,
                locality: placemark.locality
            )
        } catch {
            return fallbackName(fallbackIndex)
        }
    }

    private func fallbackName(_ index: Int) -> PlaceName {
        PlaceName(
            title: "장소 \(index + 1)",
            subtitle: nil,
            administrativeArea: nil,
            locality: nil
        )
    }
}

enum BoardGenerationError: LocalizedError {
    case notEnoughLocatedPhotos
    case mapUnavailable

    var errorDescription: String? {
        switch self {
        case .notEnoughLocatedPhotos:
            return "위치 정보가 있는 사진이 충분하지 않습니다."
        case .mapUnavailable:
            return "지도를 불러오지 못했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}

enum RegionNormalizer {
    private struct Mapping {
        let aliases: [String]
        let key: String
    }

    private static let mappings: [Mapping] = [
        Mapping(aliases: ["서울", "Seoul"], key: "서울"),
        Mapping(aliases: ["부산", "Busan"], key: "부산"),
        Mapping(aliases: ["대구", "Daegu"], key: "대구"),
        Mapping(aliases: ["인천", "Incheon"], key: "인천"),
        Mapping(aliases: ["광주", "Gwangju"], key: "광주"),
        Mapping(aliases: ["대전", "Daejeon"], key: "대전"),
        Mapping(aliases: ["울산", "Ulsan"], key: "울산"),
        Mapping(aliases: ["세종", "Sejong"], key: "세종"),
        Mapping(aliases: ["경기", "Gyeonggi"], key: "경기"),
        Mapping(aliases: ["강원", "Gangwon"], key: "강원"),
        Mapping(aliases: ["충청북", "North Chungcheong"], key: "충북"),
        Mapping(aliases: ["충청남", "South Chungcheong"], key: "충남"),
        Mapping(aliases: ["전북", "전라북", "North Jeolla"], key: "전북"),
        Mapping(aliases: ["전남", "전라남", "South Jeolla"], key: "전남"),
        Mapping(aliases: ["경상북", "North Gyeongsang"], key: "경북"),
        Mapping(aliases: ["경상남", "South Gyeongsang"], key: "경남"),
        Mapping(aliases: ["제주", "Jeju"], key: "제주"),

        Mapping(aliases: ["北海道", "Hokkaido"], key: "일본:홋카이도"),
        Mapping(aliases: ["青森", "Aomori", "岩手", "Iwate", "宮城", "Miyagi", "秋田", "Akita", "山形", "Yamagata", "福島", "Fukushima"], key: "일본:도호쿠"),
        Mapping(aliases: ["茨城", "Ibaraki", "栃木", "Tochigi", "群馬", "Gunma", "埼玉", "Saitama", "千葉", "Chiba", "東京", "Tokyo", "神奈川", "Kanagawa"], key: "일본:간토"),
        Mapping(aliases: ["新潟", "Niigata", "富山", "Toyama", "石川", "Ishikawa", "福井", "Fukui", "山梨", "Yamanashi", "長野", "Nagano", "岐阜", "Gifu", "静岡", "Shizuoka", "愛知", "Aichi"], key: "일본:주부"),
        Mapping(aliases: ["三重", "Mie", "滋賀", "Shiga", "京都", "Kyoto", "大阪", "Osaka", "兵庫", "Hyogo", "奈良", "Nara", "和歌山", "Wakayama"], key: "일본:간사이"),
        Mapping(aliases: ["鳥取", "Tottori", "島根", "Shimane", "岡山", "Okayama", "広島", "Hiroshima", "山口", "Yamaguchi"], key: "일본:주고쿠"),
        Mapping(aliases: ["徳島", "Tokushima", "香川", "Kagawa", "愛媛", "Ehime", "高知", "Kochi"], key: "일본:시코쿠"),
        Mapping(aliases: ["福岡", "Fukuoka", "佐賀", "Saga", "長崎", "Nagasaki", "熊本", "Kumamoto", "大分", "Oita", "Ōita", "宮崎", "Miyazaki", "鹿児島", "Kagoshima", "沖縄", "Okinawa"], key: "일본:규슈")
    ]

    static func key(from value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let normalizedValue = normalized(value)
        return mappings.first { mapping in
            mapping.aliases.contains { normalizedValue.contains(normalized($0)) }
        }?.key
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "prefecture", with: "")
            .replacingOccurrences(of: "metropolis", with: "")
            .replacingOccurrences(of: "province", with: "")
            .replacingOccurrences(of: "都", with: "")
            .replacingOccurrences(of: "道", with: "")
            .replacingOccurrences(of: "府", with: "")
            .replacingOccurrences(of: "県", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
