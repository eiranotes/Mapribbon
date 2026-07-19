import SwiftUI
import SwiftData
import UIKit

@main
struct MapRibbonApp: App {
    @State private var photoLibrary = PhotoLibraryService()
    @State private var store = StoreService()

    private var launchArguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if launchArguments.contains("--screenshot-board-editor") {
                    BoardEditorScreenshotFixtureView()
                } else if launchArguments.contains("--screenshot-board-canvas") {
                    BoardCanvasScreenshotFixtureView()
                } else {
                    RootView()
                }
            }
            .environment(photoLibrary)
            .environment(store)
            .tint(MRColor.accent)
            .preferredColorScheme(.light)
        }
        .modelContainer(for: SavedBoard.self)
    }
}

@MainActor
private struct BoardEditorScreenshotFixtureView: View {
    @State private var draft: BoardDraft

    init() {
        _draft = State(initialValue: BoardScreenshotFixture.makeDraft())
    }

    var body: some View {
        NavigationStack {
            BoardEditorView(draft: draft, onClose: {})
        }
    }
}

@MainActor
private struct BoardCanvasScreenshotFixtureView: View {
    @State private var draft: BoardDraft

    init() {
        _draft = State(initialValue: BoardScreenshotFixture.makeDraft())
    }

    var body: some View {
        ZStack {
            MRColor.background.ignoresSafeArea()

            BoardCanvasView(model: draft.renderModel, watermark: false)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
    }
}

@MainActor
private enum BoardScreenshotFixture {
    private struct PlaceSpec {
        let title: String
        let subtitle: String
        let symbol: String
        let colors: [UIColor]
        let point: CGPoint
        let photoCount: Int
    }

    static func makeDraft() -> BoardDraft {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 9)) ?? .now
        let specs: [PlaceSpec] = [
            PlaceSpec(
                title: "경복궁",
                subtitle: "오전 10:30–오전 11:20",
                symbol: "building.columns.fill",
                colors: [UIColor(red: 0.28, green: 0.55, blue: 0.72, alpha: 1), UIColor(red: 0.70, green: 0.84, blue: 0.88, alpha: 1)],
                point: CGPoint(x: 0.22, y: 0.28),
                photoCount: 3
            ),
            PlaceSpec(
                title: "광장시장",
                subtitle: "오후 12:10–오후 12:52",
                symbol: "storefront.fill",
                colors: [UIColor(red: 0.70, green: 0.31, blue: 0.20, alpha: 1), UIColor(red: 0.94, green: 0.69, blue: 0.28, alpha: 1)],
                point: CGPoint(x: 0.75, y: 0.30),
                photoCount: 3
            ),
            PlaceSpec(
                title: "시청 카페",
                subtitle: "오후 1:10–오후 1:38",
                symbol: "cup.and.saucer.fill",
                colors: [UIColor(red: 0.43, green: 0.34, blue: 0.27, alpha: 1), UIColor(red: 0.78, green: 0.64, blue: 0.46, alpha: 1)],
                point: CGPoint(x: 0.28, y: 0.53),
                photoCount: 3
            ),
            PlaceSpec(
                title: "덕수궁 돌담길",
                subtitle: "오후 3:20–오후 4:05",
                symbol: "tree.fill",
                colors: [UIColor(red: 0.20, green: 0.42, blue: 0.25, alpha: 1), UIColor(red: 0.62, green: 0.72, blue: 0.46, alpha: 1)],
                point: CGPoint(x: 0.25, y: 0.75),
                photoCount: 2
            ),
            PlaceSpec(
                title: "한강 야경",
                subtitle: "오후 6:10–오후 8:40",
                symbol: "moon.stars.fill",
                colors: [UIColor(red: 0.05, green: 0.13, blue: 0.27, alpha: 1), UIColor(red: 0.18, green: 0.35, blue: 0.50, alpha: 1)],
                point: CGPoint(x: 0.70, y: 0.75),
                photoCount: 3
            )
        ]

        let identifiers = specs.indices.map { "screenshot-photo-\($0)" }
        let placeIDs = specs.indices.map { index in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1)) ?? UUID()
        }

        let places = specs.enumerated().map { index, spec in
            BoardPlace(
                id: placeIDs[index],
                title: spec.title,
                subtitle: spec.subtitle,
                administrativeArea: "서울특별시",
                locality: "서울",
                latitude: 37.56 + Double(index) * 0.002,
                longitude: 126.97 + Double(index) * 0.002,
                startDate: day.addingTimeInterval(Double(index) * 7_200),
                endDate: day.addingTimeInterval(Double(index) * 7_200 + 2_400),
                assetIdentifiers: (0..<spec.photoCount).map { "\(identifiers[index])-\($0)" },
                representativeAssetIdentifier: identifiers[index],
                isHidden: false
            )
        }

        let normalizedPoints = Dictionary(uniqueKeysWithValues: specs.enumerated().map { index, spec in
            (placeIDs[index], spec.point)
        })
        let photoImages = Dictionary(uniqueKeysWithValues: specs.enumerated().map { index, spec in
            (identifiers[index], makePhoto(symbol: spec.symbol, title: spec.title, colors: spec.colors))
        })

        return BoardDraft(
            date: day,
            title: "서울 하루 산책",
            places: places,
            template: .ribbon,
            mapImage: makeMapImage(),
            normalizedPoints: normalizedPoints,
            photoImages: photoImages
        )
    }

    private static func makeMapImage() -> UIImage {
        let size = CGSize(width: 900, height: 1_200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            UIColor(red: 0.91, green: 0.88, blue: 0.81, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            context.setLineCap(.round)
            context.setLineJoin(.round)

            UIColor(red: 0.70, green: 0.72, blue: 0.68, alpha: 0.46).setStroke()
            context.setLineWidth(2)
            for index in 0..<18 {
                let y = CGFloat(55 + index * 66)
                let offset = CGFloat((index % 4) * 18)
                context.move(to: CGPoint(x: 0, y: y + offset))
                context.addCurve(
                    to: CGPoint(x: size.width, y: y - offset * 0.35),
                    control1: CGPoint(x: size.width * 0.30, y: y - 35),
                    control2: CGPoint(x: size.width * 0.66, y: y + 28)
                )
                context.strokePath()
            }

            UIColor(red: 0.74, green: 0.75, blue: 0.70, alpha: 0.34).setStroke()
            context.setLineWidth(1.4)
            for index in 0..<13 {
                let x = CGFloat(35 + index * 72)
                context.move(to: CGPoint(x: x, y: 0))
                context.addCurve(
                    to: CGPoint(x: x + CGFloat((index % 3) * 28 - 24), y: size.height),
                    control1: CGPoint(x: x - 54, y: size.height * 0.28),
                    control2: CGPoint(x: x + 64, y: size.height * 0.72)
                )
                context.strokePath()
            }

            UIColor(red: 0.64, green: 0.75, blue: 0.77, alpha: 0.52).setStroke()
            context.setLineWidth(74)
            context.move(to: CGPoint(x: 800, y: -30))
            context.addCurve(
                to: CGPoint(x: 700, y: 1_250),
                control1: CGPoint(x: 675, y: 330),
                control2: CGPoint(x: 845, y: 820)
            )
            context.strokePath()

            UIColor(red: 0.83, green: 0.80, blue: 0.69, alpha: 0.42).setFill()
            let park = UIBezierPath(roundedRect: CGRect(x: 310, y: 760, width: 290, height: 240), cornerRadius: 74)
            park.fill()

            let labels: [(String, CGPoint)] = [
                ("경복궁", CGPoint(x: 220, y: 190)),
                ("종로", CGPoint(x: 480, y: 310)),
                ("광장시장", CGPoint(x: 650, y: 440)),
                ("시청", CGPoint(x: 350, y: 640)),
                ("덕수궁", CGPoint(x: 240, y: 855)),
                ("남산", CGPoint(x: 500, y: 980)),
                ("한강", CGPoint(x: 755, y: 660))
            ]
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .medium),
                .foregroundColor: UIColor(red: 0.38, green: 0.39, blue: 0.36, alpha: 0.63)
            ]
            for (label, point) in labels {
                label.draw(at: point, withAttributes: attributes)
            }

            UIColor(red: 0.42, green: 0.40, blue: 0.35, alpha: 0.08).setFill()
            for index in 0..<150 {
                let x = CGFloat((index * 73) % 900)
                let y = CGFloat((index * 127) % 1_200)
                context.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
    }

    private static func makePhoto(symbol: String, title: String, colors: [UIColor]) -> UIImage {
        let size = CGSize(width: 700, height: 520)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map(\.cgColor) as CFArray,
                locations: [0, 1]
            )
            if let gradient {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            UIColor.white.withAlphaComponent(0.13).setFill()
            for index in 0..<7 {
                let diameter = CGFloat(80 + index * 18)
                let x = CGFloat((index * 113) % 650) - 20
                let y = CGFloat((index * 79) % 450) - 30
                context.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
            }

            let configuration = UIImage.SymbolConfiguration(pointSize: 190, weight: .semibold)
            if let image = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white.withAlphaComponent(0.88), renderingMode: .alwaysOriginal) {
                let imageSize = image.size
                let origin = CGPoint(
                    x: (size.width - imageSize.width) * 0.5,
                    y: (size.height - imageSize.height) * 0.44
                )
                image.draw(at: origin)
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            title.draw(
                in: CGRect(x: 30, y: size.height - 86, width: size.width - 60, height: 60),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                    .paragraphStyle: paragraph
                ]
            )
        }
    }
}
