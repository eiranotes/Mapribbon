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

    private let screenshotMode: Bool

    init() {
#if DEBUG
        screenshotMode = ScreenshotLaunch.isEnabled
        if screenshotMode {
            authorizationStatus = .authorized
            daySummaries = ScreenshotFixtures.photoDaySummaries
        }
#else
        screenshotMode = false
#endif
    }

    var canReadLibrary: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var isLimited: Bool {
        authorizationStatus == .limited
    }

    func refreshAuthorization() {
#if DEBUG
        if screenshotMode {
            authorizationStatus = .authorized
            daySummaries = ScreenshotFixtures.photoDaySummaries
            return
        }
#endif
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccess() async {
#if DEBUG
        if screenshotMode {
            authorizationStatus = .authorized
            daySummaries = ScreenshotFixtures.photoDaySummaries
            return
        }
#endif
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if canReadLibrary {
            await scanRecentDays()
        }
    }

    func scanRecentDays(lookbackDays: Int = 365) async {
#if DEBUG
        if screenshotMode {
            authorizationStatus = .authorized
            daySummaries = ScreenshotFixtures.photoDaySummaries
            isScanning = false
            return
        }
#endif
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

    private init() {}

    func image(
        for identifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        highQuality: Bool = false
    ) async -> UIImage? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
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
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
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
