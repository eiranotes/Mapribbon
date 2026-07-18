import SwiftUI
import UIKit

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var demoMode: DemoMode? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ci-demo-export") { return .export }
        if arguments.contains("--ci-demo-places") { return .places }
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
                    case .editor:
                        BoardEditorView(draft: draft, onClose: {})
                    case .places:
                        PlaceManagerView(draft: draft)
                    case .export:
                        ExportSheet(draft: draft) { _, _ in }
                    }
                } else if let errorMessage {
                    ContentUnavailableView("데모 보드를 만들지 못했습니다", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
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
    static func makeDraft() async throws -> BoardDraft {
        let base = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 9, minute: 10)) ?? .now
        let specs: [(String, String, UIColor, Double, Double, TimeInterval)] = [
            ("hotel-am", "HOTEL AM", UIColor(red: 0.88, green: 0.73, blue: 0.55, alpha: 1), 37.5663, 126.9779, 0),
            ("hotel-breakfast", "BREAKFAST", UIColor(red: 0.94, green: 0.61, blue: 0.47, alpha: 1), 37.5664, 126.9780, 20 * 60),
            ("palace-1", "PALACE", UIColor(red: 0.35, green: 0.60, blue: 0.62, alpha: 1), 37.5796, 126.9770, 80 * 60),
            ("palace-2", "COURTYARD", UIColor(red: 0.42, green: 0.67, blue: 0.51, alpha: 1), 37.5797, 126.9772, 105 * 60),
            ("market-1", "MARKET", UIColor(red: 0.88, green: 0.48, blue: 0.42, alpha: 1), 37.5702, 126.9997, 3 * 60 * 60),
            ("market-2", "SNACK", UIColor(red: 0.93, green: 0.73, blue: 0.32, alpha: 1), 37.5704, 126.9999, 3.4 * 60 * 60),
            ("hotel-pm", "HOTEL PM", UIColor(red: 0.40, green: 0.44, blue: 0.58, alpha: 1), 37.5662, 126.9781, 9 * 60 * 60),
            ("hotel-night", "NIGHT", UIColor(red: 0.24, green: 0.28, blue: 0.39, alpha: 1), 37.5663, 126.9780, 9.4 * 60 * 60)
        ]

        let assets = specs.map { spec in
            PhotoAssetSnapshot(
                id: spec.0,
                creationDate: base.addingTimeInterval(spec.5),
                latitude: spec.3,
                longitude: spec.4,
                pixelWidth: 1600,
                pixelHeight: 1200,
                isFavorite: spec.0 == "palace-1" || spec.0 == "market-1",
                isScreenshot: false
            )
        }

        let clusters = PhotoClusterer.cluster(assets)
        let placeNames = ["시청 호텔", "경복궁", "광장시장", "시청 호텔"]
        let subtitles = ["아침 출발", "궁궐 산책", "점심과 시장", "저녁 재방문"]

        var places: [BoardPlace] = []
        var normalizedPoints: [UUID: CGPoint] = [:]
        for (index, cluster) in clusters.enumerated() {
            let representative = PhotoClusterer.representative(in: cluster.assets) ?? cluster.assets[0]
            let place = BoardPlace(
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
            places.append(place)
        }

        let mapResult = try await MapSnapshotService().snapshot(for: places, size: CGSize(width: 900, height: 1200))
        normalizedPoints = mapResult.normalizedPoints

        let images = Dictionary(uniqueKeysWithValues: specs.map { spec in
            (spec.0, demoImage(title: spec.1, color: spec.2))
        })

        return BoardDraft(
            date: Calendar(identifier: .gregorian).startOfDay(for: base),
            title: "서울 하루 산책",
            caption: "사진으로 다시 엮은 여름의 하루",
            places: places,
            template: .pinboard,
            mapImage: mapResult.image,
            normalizedPoints: normalizedPoints,
            photoImages: images,
            sourceAssets: assets
        )
    }

    private static func demoImage(title: String, color: UIColor) -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.16).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 650, y: -120, width: 650, height: 650))
            UIColor.black.withAlphaComponent(0.10).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: -180, y: 470, width: 620, height: 620))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 92, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            NSString(string: title).draw(in: CGRect(x: 90, y: 355, width: 1020, height: 140), withAttributes: attributes)
        }
    }
}
