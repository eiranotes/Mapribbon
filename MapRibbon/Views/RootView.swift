import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
#if DEBUG
            if let route = ScreenshotRoute.current {
                ScreenshotRootView(route: route)
            } else if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
#else
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
#endif
        }
        .background(MRColor.background.ignoresSafeArea())
    }
}

enum MainTab: Hashable {
    case boards
    case atlas
    case settings
}

struct MainTabView: View {
    @State private var selection: MainTab

    init(selection: MainTab = .boards) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { BoardsHomeView() }
                .tabItem { Label("보드", systemImage: "rectangle.stack") }
                .tag(MainTab.boards)

            NavigationStack { AtlasView() }
                .tabItem { Label("아틀라스", systemImage: "map") }
                .tag(MainTab.atlas)

            NavigationStack { SettingsView() }
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
    }
}

#if DEBUG
enum ScreenshotLaunch {
    static var routeName: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--screenshot-route"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    static var isEnabled: Bool {
        routeName != nil
    }
}

private enum ScreenshotRoute: String {
    case onboarding
    case permission
    case boards
    case dates
    case generation
    case editor
    case places
    case placeEditor = "place-editor"
    case export
    case savedBoard = "saved-board"
    case atlas
    case settings
    case paywall

    static var current: ScreenshotRoute? {
        ScreenshotLaunch.routeName.flatMap(ScreenshotRoute.init(rawValue:))
    }
}

private struct ScreenshotRootView: View {
    let route: ScreenshotRoute
    @State private var draft: BoardDraft

    init(route: ScreenshotRoute) {
        self.route = route
        _draft = State(initialValue: ScreenshotFixtures.makeDraft())
    }

    @ViewBuilder
    var body: some View {
        switch route {
        case .onboarding:
            OnboardingView(onComplete: {})
        case .permission:
            ScreenshotPermissionHost()
        case .boards:
            MainTabView(selection: .boards)
        case .dates:
            NavigationStack {
                DateSelectionView(onSelect: { _ in })
            }
        case .generation:
            NavigationStack {
                GenerationProgressView(step: .preparingMap, progress: 0.72)
                    .navigationTitle("새 보드")
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .editor:
            NavigationStack {
                BoardEditorView(draft: draft, onClose: {})
            }
        case .places:
            PlaceManagerView(draft: draft)
        case .placeEditor:
            ScreenshotPlaceEditorHost()
        case .export:
            ExportSheet(draft: draft, onExport: { _, _ in })
        case .savedBoard:
            NavigationStack {
                SavedBoardDetailView(board: ScreenshotFixtures.makeSavedBoard())
            }
        case .atlas:
            ScreenshotSeededMainTab(selection: .atlas)
        case .settings:
            MainTabView(selection: .settings)
        case .paywall:
            PaywallView()
        }
    }
}

private struct ScreenshotPermissionHost: View {
    @State private var isPresented = true

    var body: some View {
        MRColor.background
            .ignoresSafeArea()
            .sheet(isPresented: $isPresented) {
                PermissionExplainerView(
                    isRequesting: false,
                    onContinue: {},
                    onContinueWithoutAccess: {}
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

private struct ScreenshotPlaceEditorHost: View {
    @State private var place: BoardPlace
    @State private var draft: BoardDraft

    init() {
        let fixture = ScreenshotFixtures.makeDraft()
        _draft = State(initialValue: fixture)
        _place = State(initialValue: fixture.places[0])
    }

    var body: some View {
        NavigationStack {
            PlaceEditorView(place: $place, draft: draft)
        }
    }
}

private struct ScreenshotSeededMainTab: View {
    let selection: MainTab
    @Environment(\.modelContext) private var modelContext
    @State private var didSeed = false

    var body: some View {
        MainTabView(selection: selection)
            .task {
                guard !didSeed else { return }
                didSeed = true
                for board in ScreenshotFixtures.makeAtlasBoards() {
                    modelContext.insert(board)
                }
                try? modelContext.save()
            }
    }
}

@MainActor
enum ScreenshotFixtures {
    static let fixedDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 9
        components.minute = 30
        return components.date ?? Date(timeIntervalSince1970: 1_779_000_000)
    }()

    static var photoDaySummaries: [PhotoDaySummary] {
        [
            makeSummary(dayOffset: 0, cityLatitude: 37.5665, cityLongitude: 126.9780, count: 18),
            makeSummary(dayOffset: -3, cityLatitude: 35.1796, cityLongitude: 129.0756, count: 12),
            makeSummary(dayOffset: -12, cityLatitude: 33.4996, cityLongitude: 126.5312, count: 9),
            makeSummary(dayOffset: -28, cityLatitude: 37.4563, cityLongitude: 126.7052, count: 7)
        ]
    }

    static func makeDraft(template: BoardTemplate = .ribbon) -> BoardDraft {
        let placeIDs = [
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        ]
        let names = ["서울숲", "성수동 골목", "남산 전망대", "한강공원"]
        let subtitles = ["초록이 짙었던 오전", "작은 상점과 카페", "도시를 내려다본 시간", "해 질 무렵의 산책"]
        let coordinates = [
            (37.5444, 127.0374),
            (37.5423, 127.0567),
            (37.5512, 126.9882),
            (37.5284, 126.9348)
        ]

        var places: [BoardPlace] = []
        var images: [String: UIImage] = [:]
        let symbols = ["leaf.fill", "cup.and.saucer.fill", "building.2.fill", "sunset.fill"]
        let colors = [
            UIColor(red: 0.43, green: 0.65, blue: 0.56, alpha: 1),
            UIColor(red: 0.76, green: 0.52, blue: 0.39, alpha: 1),
            UIColor(red: 0.40, green: 0.55, blue: 0.71, alpha: 1),
            UIColor(red: 0.88, green: 0.56, blue: 0.39, alpha: 1)
        ]

        for index in names.indices {
            let identifiers = (1...3).map { "fixture-\(index + 1)-\($0)" }
            for (photoIndex, identifier) in identifiers.enumerated() {
                images[identifier] = makePhotoImage(
                    color: colors[(index + photoIndex) % colors.count],
                    symbol: symbols[index],
                    label: names[index]
                )
            }

            places.append(
                BoardPlace(
                    id: placeIDs[index],
                    title: names[index],
                    subtitle: subtitles[index],
                    administrativeArea: "서울특별시",
                    locality: names[index],
                    latitude: coordinates[index].0,
                    longitude: coordinates[index].1,
                    startDate: fixedDate.addingTimeInterval(Double(index) * 7_200),
                    endDate: fixedDate.addingTimeInterval(Double(index) * 7_200 + 2_400),
                    assetIdentifiers: identifiers,
                    representativeAssetIdentifier: identifiers[0],
                    isHidden: false
                )
            )
        }

        return BoardDraft(
            date: fixedDate,
            title: "서울의 봄날 산책",
            places: places,
            template: template,
            mapImage: makeMapImage(),
            normalizedPoints: [
                placeIDs[0]: CGPoint(x: 0.25, y: 0.30),
                placeIDs[1]: CGPoint(x: 0.68, y: 0.39),
                placeIDs[2]: CGPoint(x: 0.52, y: 0.58),
                placeIDs[3]: CGPoint(x: 0.30, y: 0.76)
            ],
            photoImages: images
        )
    }

    static func makeSavedBoard() -> SavedBoard {
        let preview = makeBoardPreviewImage()
        return SavedBoard(
            date: fixedDate,
            title: "서울의 봄날 산책",
            photoCount: 18,
            placeCount: 4,
            templateRawValue: BoardTemplate.ribbon.rawValue,
            previewImageData: preview.jpegData(compressionQuality: 0.9) ?? Data(),
            payloadData: Data("{}".utf8),
            regionKeysJSON: "[\"서울\",\"경기\"]"
        )
    }

    static func makeAtlasBoards() -> [SavedBoard] {
        let previewData = makeBoardPreviewImage().jpegData(compressionQuality: 0.82) ?? Data()
        let regions = [
            "[\"서울\",\"경기\",\"인천\"]",
            "[\"부산\",\"경남\",\"울산\"]",
            "[\"제주\"]",
            "[\"강원\",\"충북\"]"
        ]
        let titles = ["서울의 봄날 산책", "부산 바다 하루", "제주 동쪽 드라이브", "강원 숲과 호수"]
        var boards: [SavedBoard] = []
        boards.reserveCapacity(titles.count)

        for index in titles.indices {
            let board = SavedBoard(
                date: fixedDate.addingTimeInterval(Double(-index) * 86_400 * 10),
                createdAt: fixedDate.addingTimeInterval(Double(-index) * 3_600),
                title: titles[index],
                photoCount: 8 + index * 3,
                placeCount: 3 + index,
                templateRawValue: BoardTemplate.allCases[index % BoardTemplate.allCases.count].rawValue,
                previewImageData: previewData,
                payloadData: Data("{}".utf8),
                regionKeysJSON: regions[index]
            )
            boards.append(board)
        }
        return boards
    }

    private static func makeSummary(
        dayOffset: Int,
        cityLatitude: Double,
        cityLongitude: Double,
        count: Int
    ) -> PhotoDaySummary {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: dayOffset, to: fixedDate) ?? fixedDate
        var assets: [PhotoAssetSnapshot] = []
        assets.reserveCapacity(count)

        for index in 0..<count {
            let creationDate = date.addingTimeInterval(Double(index) * 1_100)
            let latitudeOffset = Double(index % 4) * 0.007
            let longitudeOffset = Double(index % 3) * 0.008
            let asset = PhotoAssetSnapshot(
                id: "summary-\(dayOffset)-\(index)",
                creationDate: creationDate,
                latitude: cityLatitude + latitudeOffset,
                longitude: cityLongitude + longitudeOffset,
                pixelWidth: 4_032,
                pixelHeight: 3_024,
                isFavorite: index == 0,
                isScreenshot: false
            )
            assets.append(asset)
        }

        return PhotoDaySummary(date: date, assets: assets)
    }

    private static func makePhotoImage(color: UIColor, symbol: String, label: String) -> UIImage {
        let size = CGSize(width: 720, height: 720)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.14).setFill()
            UIBezierPath(ovalIn: CGRect(x: 70, y: 70, width: 580, height: 580)).fill()

            let configuration = UIImage.SymbolConfiguration(pointSize: 170, weight: .semibold)
            if let icon = UIImage(systemName: symbol, withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(in: CGRect(x: 275, y: 205, width: 170, height: 170))
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            (label as NSString).draw(
                in: CGRect(x: 40, y: 520, width: 640, height: 80),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 38, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
            )
        }
    }

    private static func makeMapImage() -> UIImage {
        let size = CGSize(width: 900, height: 1_600)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            UIColor(red: 0.90, green: 0.89, blue: 0.83, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.69, green: 0.82, blue: 0.84, alpha: 1).setFill()
            let river = UIBezierPath()
            river.move(to: CGPoint(x: -80, y: 1_020))
            river.addCurve(
                to: CGPoint(x: 980, y: 810),
                controlPoint1: CGPoint(x: 250, y: 850),
                controlPoint2: CGPoint(x: 610, y: 1_050)
            )
            river.addLine(to: CGPoint(x: 980, y: 1_080))
            river.addCurve(
                to: CGPoint(x: -80, y: 1_270),
                controlPoint1: CGPoint(x: 570, y: 1_210),
                controlPoint2: CGPoint(x: 280, y: 1_050)
            )
            river.close()
            river.fill()

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.72).cgColor)
            cg.setLineWidth(10)
            for index in 0..<8 {
                let y = CGFloat(170 + index * 150)
                cg.move(to: CGPoint(x: 40, y: y))
                cg.addCurve(
                    to: CGPoint(x: 860, y: y + CGFloat(index.isMultiple(of: 2) ? 70 : -45)),
                    control1: CGPoint(x: 270, y: y - 75),
                    control2: CGPoint(x: 610, y: y + 90)
                )
                cg.strokePath()
            }

            cg.setStrokeColor(UIColor(red: 0.76, green: 0.72, blue: 0.63, alpha: 0.75).cgColor)
            cg.setLineWidth(3)
            for x in stride(from: 90, through: 810, by: 120) {
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x - 80, y: 1_600))
                cg.strokePath()
            }

            ("SEOUL" as NSString).draw(
                at: CGPoint(x: 60, y: 1_430),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 78, weight: .black),
                    .foregroundColor: UIColor.black.withAlphaComponent(0.12)
                ]
            )
        }
    }

    private static func makeBoardPreviewImage() -> UIImage {
        let size = CGSize(width: 900, height: 1_600)
        let map = makeMapImage()
        return UIGraphicsImageRenderer(size: size).image { _ in
            map.draw(in: CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.78).setFill()
            UIBezierPath(roundedRect: CGRect(x: 55, y: 70, width: 790, height: 210), cornerRadius: 28).fill()
            ("서울의 봄날 산책" as NSString).draw(
                in: CGRect(x: 95, y: 120, width: 710, height: 90),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 58, weight: .bold),
                    .foregroundColor: UIColor(red: 0.15, green: 0.14, blue: 0.12, alpha: 1)
                ]
            )
            ("2026. 5. 16 · 사진 18장 · 장소 4곳" as NSString).draw(
                in: CGRect(x: 98, y: 215, width: 690, height: 45),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                    .foregroundColor: UIColor.darkGray
                ]
            )
        }
    }
}
#endif
