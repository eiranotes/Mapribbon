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
        let latitudeDelta = max(0.015, (maxLat - minLat) * 1.55)
        let longitudeDelta = max(0.015, (maxLon - minLon) * 1.55)

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
                    subtitle: placeName.subtitle,
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
    static func key(from value: String?) -> String? {
        guard let value else { return nil }
        let mappings: [(String, String)] = [
            ("서울", "서울"), ("Seoul", "서울"),
            ("부산", "부산"), ("Busan", "부산"),
            ("대구", "대구"), ("Daegu", "대구"),
            ("인천", "인천"), ("Incheon", "인천"),
            ("광주", "광주"), ("Gwangju", "광주"),
            ("대전", "대전"), ("Daejeon", "대전"),
            ("울산", "울산"), ("Ulsan", "울산"),
            ("세종", "세종"), ("Sejong", "세종"),
            ("경기", "경기"), ("Gyeonggi", "경기"),
            ("강원", "강원"), ("Gangwon", "강원"),
            ("충청북", "충북"), ("North Chungcheong", "충북"),
            ("충청남", "충남"), ("South Chungcheong", "충남"),
            ("전북", "전북"), ("전라북", "전북"), ("North Jeolla", "전북"),
            ("전남", "전남"), ("전라남", "전남"), ("South Jeolla", "전남"),
            ("경상북", "경북"), ("North Gyeongsang", "경북"),
            ("경상남", "경남"), ("South Gyeongsang", "경남"),
            ("제주", "제주"), ("Jeju", "제주"),
            ("北海道", "일본:홋카이도"), ("Hokkaido", "일본:홋카이도"),
            ("青森", "일본:도호쿠"), ("岩手", "일본:도호쿠"), ("宮城", "일본:도호쿠"), ("秋田", "일본:도호쿠"), ("山形", "일본:도호쿠"), ("福島", "일본:도호쿠"),
            ("Tokyo", "일본:간토"), ("東京", "일본:간토"), ("Kanagawa", "일본:간토"), ("神奈川", "일본:간토"), ("Chiba", "일본:간토"), ("千葉", "일본:간토"), ("Saitama", "일본:간토"), ("埼玉", "일본:간토"),
            ("Aichi", "일본:주부"), ("愛知", "일본:주부"), ("Nagano", "일본:주부"), ("長野", "일본:주부"), ("Shizuoka", "일본:주부"), ("静岡", "일본:주부"), ("Niigata", "일본:주부"), ("新潟", "일본:주부"),
            ("Osaka", "일본:간사이"), ("大阪", "일본:간사이"), ("Kyoto", "일본:간사이"), ("京都", "일본:간사이"), ("Hyogo", "일본:간사이"), ("兵庫", "일본:간사이"), ("Nara", "일본:간사이"), ("奈良", "일본:간사이"),
            ("Hiroshima", "일본:주고쿠"), ("広島", "일본:주고쿠"), ("Okayama", "일본:주고쿠"), ("岡山", "일본:주고쿠"),
            ("Kagawa", "일본:시코쿠"), ("香川", "일본:시코쿠"), ("Ehime", "일본:시코쿠"), ("愛媛", "일본:시코쿠"),
            ("Fukuoka", "일본:규슈"), ("福岡", "일본:규슈"), ("Kumamoto", "일본:규슈"), ("熊本", "일본:규슈"), ("Nagasaki", "일본:규슈"), ("長崎", "일본:규슈"), ("Okinawa", "일본:규슈"), ("沖縄", "일본:규슈")
        ]
        return mappings.first(where: { value.localizedCaseInsensitiveContains($0.0) })?.1
    }
}
