import Foundation
import Photos
import PhotosUI
import UIKit
import Observation

@MainActor
@Observable
final class PhotoLibraryService {
    private(set) var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var daySummaries: [PhotoDaySummary] = []
    private(set) var isScanning = false
    var errorMessage: String?

    var canReadLibrary: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var isLimited: Bool {
        authorizationStatus == .limited
    }

    func refreshAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccess() async {
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if canReadLibrary {
            await scanRecentDays()
        }
    }

    func scanRecentDays(lookbackDays: Int = 365) async {
        refreshAuthorization()
        guard canReadLibrary else {
            daySummaries = []
            return
        }

        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        let calendar = Calendar.autoupdatingCurrent
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: .now) ?? .distantPast
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@",
            PHAssetMediaType.image.rawValue,
            cutoff as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 5000

        let result = PHAsset.fetchAssets(with: options)
        var grouped: [Date: [PhotoAssetSnapshot]] = [:]

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate,
                  let location = asset.location else { return }

            let snapshot = PhotoAssetSnapshot(
                id: asset.localIdentifier,
                creationDate: date,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                isFavorite: asset.isFavorite,
                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
            )

            let day = calendar.startOfDay(for: date)
            grouped[day, default: []].append(snapshot)
        }

        daySummaries = grouped
            .map { day, assets in
                PhotoDaySummary(
                    date: day,
                    assets: assets.sorted { $0.creationDate < $1.creationDate }
                )
            }
            .filter { $0.photoCount >= 2 }
            .sorted { $0.date > $1.date }
    }

    func showLimitedLibraryPicker() {
        guard let controller = UIApplication.shared.mrTopViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }
}

@MainActor
final class PhotoImageService {
    static let shared = PhotoImageService()
    private let manager = PHCachingImageManager()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 120
    }

    func register(_ images: [String: UIImage]) {
        for (identifier, image) in images {
            cache.setObject(image, forKey: identifier as NSString)
        }
    }

    func cachedImage(for identifier: String) -> UIImage? {
        cache.object(forKey: identifier as NSString)
    }

    func image(
        for identifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        highQuality: Bool = false
    ) async -> UIImage? {
        if let cached = cache.object(forKey: identifier as NSString) {
            return cached
        }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.resizeMode = highQuality ? .exact : .fast
            options.deliveryMode = highQuality ? .highQualityFormat : .fastFormat
            options.isSynchronous = false

            var resumed = false
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                guard !resumed else { return }
                let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
                let hasError = info?[PHImageErrorKey] != nil
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true

                if cancelled || hasError {
                    resumed = true
                    continuation.resume(returning: nil)
                    return
                }

                if let image, !highQuality || !degraded {
                    self.cache.setObject(image, forKey: identifier as NSString)
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func preload(
        identifiers: [String],
        targetSize: CGSize,
        limit: Int? = nil,
        highQuality: Bool = false
    ) async -> [String: UIImage] {
        var output: [String: UIImage] = [:]
        let ids = limit.map { Array(identifiers.prefix($0)) } ?? identifiers
        for identifier in ids {
            if let image = await image(
                for: identifier,
                targetSize: targetSize,
                highQuality: highQuality
            ) {
                output[identifier] = image
            }
        }
        return output
    }
}

@MainActor
enum PhotoSaveService {
    static func save(_ image: UIImage) async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status: PHAuthorizationStatus
        if current == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            status = current
        }

        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

enum PhotoSaveError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "사진 보관함에 저장할 권한이 없습니다."
    }
}

@MainActor
enum InstagramShareService {
    static var isAvailable: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func shareStory(image: UIImage) async -> Bool {
        guard let data = image.pngData(),
              let url = URL(string: "instagram-stories://share"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }

        let item: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": data
        ]
        UIPasteboard.general.setItems(
            [item],
            options: [
                .expirationDate: Date().addingTimeInterval(5 * 60),
                .localOnly: true
            ]
        )

        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
    }
}

extension UIApplication {
    var mrTopViewController: UIViewController? {
        guard let scene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }

        func top(from controller: UIViewController) -> UIViewController {
            if let navigation = controller as? UINavigationController,
               let visible = navigation.visibleViewController {
                return top(from: visible)
            }
            if let tab = controller as? UITabBarController,
               let selected = tab.selectedViewController {
                return top(from: selected)
            }
            if let presented = controller.presentedViewController {
                return top(from: presented)
            }
            return controller
        }

        return top(from: root)
    }
}
