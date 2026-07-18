import SwiftUI
import UIKit

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var demoMode: DemoMode? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ci-demo-export") { return .export }
        if arguments.contains("--ci-demo-places") { return .places }
        if arguments.contains("--ci-demo-gallery") { return .gallery }
        if arguments.contains("--ci-demo-editor") { return .editor }
        return nil
    }

    var body: some View {
        Group {
            if let demoMode {
                DemoHarnessView(mode: demoMode)
            } else if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .background(MRColor.background.ignoresSafeArea())
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { BoardsHomeView() }
                .tabItem { Label("보드", systemImage: "rectangle.stack") }

            NavigationStack { AtlasView() }
                .tabItem { Label("아틀라스", systemImage: "map") }

            NavigationStack { SettingsView() }
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

private enum DemoMode {
    case editor
    case gallery
    case places
    case export
}

private struct DemoHarnessView: View {
    let mode: DemoMode
    @State private var draft: BoardDraft?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    switch mode {
                    case .editor, .gallery:
                        BoardEditorView(draft: draft, onClose: {})
                    case .places:
                        PlaceManagerView(draft: draft)
                    case .export:
                        ExportSheet(draft: draft) { _, _ in }
                    }
                } else if let errorMessage {
                    ContentUnavailableView(
                        "데모 보드를 만들지 못했습니다",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ProgressView("데모 보드 준비 중")
                        .tint(MRColor.accent)
                }
            }
            .background(MRColor.background.ignoresSafeArea())
        }
        .task {
            do {
                draft = try await DemoFixtureFactory.makeDraft()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
private enum DemoFixtureFactory {
    private enum Scene {
        case hotel
        case palace
        case market
        case night
    }

    private struct PhotoSpec {
        let id: String
        let scene: Scene
        let variant: Int
        let latitude: Double
        let longitude: Double
        let offset: TimeInterval
        let favorite: Bool
    }

    static func makeDraft() async throws -> BoardDraft {
        let base = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 18, hour: 9, minute: 10)
        ) ?? .now

        let specs: [PhotoSpec] = [
            .init(id: "hotel-1", scene: .hotel, variant: 0, latitude: 37.5663, longitude: 126.9779, offset: 0, favorite: true),
            .init(id: "hotel-2", scene: .hotel, variant: 1, latitude: 37.5664, longitude: 126.9780, offset: 12 * 60, favorite: false),
            .init(id: "hotel-3", scene: .hotel, variant: 2, latitude: 37.5662, longitude: 126.9781, offset: 28 * 60, favorite: false),

            .init(id: "palace-1", scene: .palace, variant: 0, latitude: 37.5796, longitude: 126.9770, offset: 80 * 60, favorite: true),
            .init(id: "palace-2", scene: .palace, variant: 1, latitude: 37.5797, longitude: 126.9772, offset: 105 * 60, favorite: false),
            .init(id: "palace-3", scene: .palace, variant: 2, latitude: 37.5795, longitude: 126.9768, offset: 130 * 60, favorite: false),

            .init(id: "market-1", scene: .market, variant: 0, latitude: 37.5702, longitude: 126.9997, offset: 3 * 60 * 60, favorite: true),
            .init(id: "market-2", scene: .market, variant: 1, latitude: 37.5704, longitude: 126.9999, offset: 3.3 * 60 * 60, favorite: false),
            .init(id: "market-3", scene: .market, variant: 2, latitude: 37.5701, longitude: 126.9995, offset: 3.7 * 60 * 60, favorite: false),

            .init(id: "night-1", scene: .night, variant: 0, latitude: 37.5662, longitude: 126.9781, offset: 9 * 60 * 60, favorite: false),
            .init(id: "night-2", scene: .night, variant: 1, latitude: 37.5663, longitude: 126.9780, offset: 9.25 * 60 * 60, favorite: true),
            .init(id: "night-3", scene: .night, variant: 2, latitude: 37.5664, longitude: 126.9779, offset: 9.5 * 60 * 60, favorite: false)
        ]

        let assets = specs.map { spec in
            PhotoAssetSnapshot(
                id: spec.id,
                creationDate: base.addingTimeInterval(spec.offset),
                latitude: spec.latitude,
                longitude: spec.longitude,
                pixelWidth: 1600,
                pixelHeight: 1200,
                isFavorite: spec.favorite,
                isScreenshot: false
            )
        }

        let clusters = PhotoClusterer.cluster(assets)
        let placeNames = ["시청 호텔", "경복궁", "광장시장", "시청 호텔"]
        let subtitles = ["아침 출발", "궁궐 산책", "점심과 시장", "저녁 재방문"]

        let places = clusters.enumerated().map { index, cluster in
            let representative = PhotoClusterer.representative(in: cluster.assets) ?? cluster.assets[0]
            return BoardPlace(
                id: cluster.id,
                title: placeNames.indices.contains(index) ? placeNames[index] : "장소 \(index + 1)",
                subtitle: subtitles.indices.contains(index) ? subtitles[index] : nil,
                administrativeArea: "서울특별시",
                locality: "서울",
                latitude: cluster.latitude,
                longitude: cluster.longitude,
                startDate: cluster.startDate,
                endDate: cluster.endDate,
                assetIdentifiers: cluster.assets.map(\.id),
                representativeAssetIdentifier: representative.id,
                isHidden: false,
                sourceAssetIdentifiers: cluster.assets.map(\.id),
                note: index == clusters.count - 1 ? "재방문" : nil
            )
        }

        let mapResult = try await MapSnapshotService().snapshot(
            for: places,
            size: CGSize(width: 900, height: 1200)
        )

        let images = Dictionary(uniqueKeysWithValues: specs.map { spec in
            (spec.id, demoImage(scene: spec.scene, variant: spec.variant))
        })
        PhotoImageService.shared.register(images)

        return BoardDraft(
            date: Calendar(identifier: .gregorian).startOfDay(for: base),
            title: "서울 하루 산책",
            caption: "사진으로 다시 엮은 여름의 하루",
            places: places,
            template: .pinboard,
            mapImage: mapResult.image,
            normalizedPoints: mapResult.normalizedPoints,
            photoImages: images,
            sourceAssets: assets
        )
    }

    private static func demoImage(scene: Scene, variant: Int) -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let rect = CGRect(origin: .zero, size: size)

            switch scene {
            case .hotel:
                drawGradient(
                    context,
                    colors: [UIColor(red: 0.98, green: 0.78, blue: 0.57, alpha: 1), UIColor(red: 0.61, green: 0.72, blue: 0.78, alpha: 1)],
                    rect: rect
                )
                drawHotel(context, size: size, variant: variant)
            case .palace:
                drawGradient(
                    context,
                    colors: [UIColor(red: 0.52, green: 0.76, blue: 0.88, alpha: 1), UIColor(red: 0.90, green: 0.86, blue: 0.70, alpha: 1)],
                    rect: rect
                )
                drawPalace(context, size: size, variant: variant)
            case .market:
                drawGradient(
                    context,
                    colors: [UIColor(red: 0.96, green: 0.74, blue: 0.44, alpha: 1), UIColor(red: 0.72, green: 0.31, blue: 0.25, alpha: 1)],
                    rect: rect
                )
                drawMarket(context, size: size, variant: variant)
            case .night:
                drawGradient(
                    context,
                    colors: [UIColor(red: 0.10, green: 0.14, blue: 0.25, alpha: 1), UIColor(red: 0.25, green: 0.29, blue: 0.43, alpha: 1)],
                    rect: rect
                )
                drawNight(context, size: size, variant: variant)
            }

            addVignette(context, rect: rect)
            addGrain(context, size: size, seed: UInt64(variant + 1) * 7_919)
        }
    }

    private static func drawGradient(_ context: CGContext, colors: [UIColor], rect: CGRect) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: [0, 1]
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    private static func drawHotel(_ context: CGContext, size: CGSize, variant: Int) {
        UIColor.white.withAlphaComponent(0.38).setFill()
        context.fill(CGRect(x: 80, y: 90, width: 1040, height: 480))
        UIColor(red: 0.24, green: 0.32, blue: 0.38, alpha: 0.48).setFill()
        for index in 0..<9 {
            let width = CGFloat(70 + (index % 3) * 28)
            let height = CGFloat(130 + ((index + variant) % 4) * 45)
            context.fill(CGRect(x: CGFloat(95 + index * 115), y: 570 - height, width: width, height: height))
        }

        UIColor(red: 0.52, green: 0.31, blue: 0.19, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 610, width: size.width, height: 290))
        UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1).setFill()
        context.fillEllipse(in: CGRect(x: 170 + variant * 35, y: 650, width: 330, height: 120))
        UIColor(red: 0.96, green: 0.96, blue: 0.93, alpha: 1).setFill()
        context.fillEllipse(in: CGRect(x: 650 - variant * 20, y: 615, width: 190, height: 190))
        UIColor(red: 0.30, green: 0.18, blue: 0.12, alpha: 1).setFill()
        context.fillEllipse(in: CGRect(x: 685 - variant * 20, y: 650, width: 120, height: 120))
        UIColor(red: 0.86, green: 0.53, blue: 0.22, alpha: 1).setFill()
        context.fillEllipse(in: CGRect(x: 235 + variant * 35, y: 665, width: 190, height: 80))
    }

    private static func drawPalace(_ context: CGContext, size: CGSize, variant: Int) {
        UIColor(red: 0.36, green: 0.56, blue: 0.31, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 570, width: size.width, height: 330))
        UIColor(red: 0.76, green: 0.21, blue: 0.16, alpha: 1).setFill()
        for index in 0..<6 {
            context.fill(CGRect(x: CGFloat(160 + index * 160 + variant * 6), y: 405, width: 48, height: 270))
        }
        UIColor(red: 0.16, green: 0.23, blue: 0.22, alpha: 1).setFill()
        var roof = CGMutablePath()
        roof.move(to: CGPoint(x: 90, y: 410))
        roof.addLine(to: CGPoint(x: 600, y: 250 - variant * 12))
        roof.addLine(to: CGPoint(x: 1110, y: 410))
        roof.closeSubpath()
        context.addPath(roof)
        context.fillPath()
        UIColor(red: 0.93, green: 0.72, blue: 0.31, alpha: 1).setStroke()
        context.setLineWidth(14)
        context.stroke(CGRect(x: 120, y: 420, width: 960, height: 18))
        UIColor.white.withAlphaComponent(0.18).setFill()
        context.fillEllipse(in: CGRect(x: 750, y: 60, width: 300, height: 180))
    }

    private static func drawMarket(_ context: CGContext, size: CGSize, variant: Int) {
        UIColor(red: 0.18, green: 0.16, blue: 0.13, alpha: 0.50).setFill()
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: 150))
        let awningColors: [UIColor] = [
            UIColor(red: 0.84, green: 0.17, blue: 0.18, alpha: 1),
            UIColor(red: 0.20, green: 0.53, blue: 0.47, alpha: 1),
            UIColor(red: 0.95, green: 0.73, blue: 0.23, alpha: 1)
        ]
        for index in 0..<5 {
            awningColors[(index + variant) % awningColors.count].setFill()
            context.fill(CGRect(x: CGFloat(index * 250 - 30), y: CGFloat(170 + (index % 2) * 45), width: 230, height: 120))
        }
        UIColor(red: 0.35, green: 0.20, blue: 0.12, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 610, width: size.width, height: 290))
        for index in 0..<9 {
            let colors = [UIColor.systemRed, UIColor.systemOrange, UIColor.systemGreen, UIColor.systemYellow]
            colors[(index + variant) % colors.count].withAlphaComponent(0.90).setFill()
            context.fillEllipse(in: CGRect(x: CGFloat(70 + index * 125), y: CGFloat(610 + (index % 3) * 65), width: 110, height: 90))
        }
        UIColor(red: 0.96, green: 0.84, blue: 0.52, alpha: 0.88).setFill()
        for index in 0..<6 {
            context.fillEllipse(in: CGRect(x: CGFloat(120 + index * 185), y: CGFloat(75 + (index % 2) * 18), width: 42, height: 42))
        }
    }

    private static func drawNight(_ context: CGContext, size: CGSize, variant: Int) {
        UIColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1).setFill()
        for index in 0..<8 {
            let height = CGFloat(260 + ((index + variant) % 4) * 90)
            context.fill(CGRect(x: CGFloat(index * 165 - 40), y: 900 - height, width: 140, height: height))
        }
        let window = UIColor(red: 0.98, green: 0.76, blue: 0.34, alpha: 0.90)
        window.setFill()
        for row in 0..<5 {
            for column in 0..<9 where (row + column + variant) % 3 != 0 {
                context.fill(CGRect(x: CGFloat(35 + column * 130), y: CGFloat(455 + row * 75), width: 32, height: 24))
            }
        }
        UIColor(red: 0.98, green: 0.89, blue: 0.72, alpha: 0.82).setFill()
        context.fillEllipse(in: CGRect(x: 820 - variant * 30, y: 90, width: 150, height: 150))
        UIColor.white.withAlphaComponent(0.42).setFill()
        context.fillEllipse(in: CGRect(x: 855 - variant * 30, y: 120, width: 42, height: 42))
    }

    private static func addVignette(_ context: CGContext, rect: CGRect) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.22).cgColor] as CFArray,
            locations: [0.55, 1]
        ) else { return }
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: rect.midX, y: rect.midY),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.midY),
            endRadius: max(rect.width, rect.height) * 0.72,
            options: [.drawsAfterEndLocation]
        )
    }

    private static func addGrain(_ context: CGContext, size: CGSize, seed: UInt64) {
        var state = seed
        for _ in 0..<1_100 {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let x = CGFloat((state >> 16) % UInt64(Int(size.width)))
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let y = CGFloat((state >> 16) % UInt64(Int(size.height)))
            let alpha = CGFloat((state >> 32) % 100) / 5_000 + 0.006
            UIColor.white.withAlphaComponent(alpha).setFill()
            context.fill(CGRect(x: x, y: y, width: 1.2, height: 1.2))
        }
    }
}
