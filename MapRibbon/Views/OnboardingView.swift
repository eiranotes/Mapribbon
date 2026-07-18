import SwiftUI
import Photos
import UIKit

struct OnboardingView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    let onComplete: () -> Void

    @State private var showingPermission = false
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            MRColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(MRColor.accent)
                            .frame(width: 46, height: 46)
                            .background(MRColor.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MapRibbon")
                                .font(.system(size: 24, weight: .bold))
                            Text("사진으로 만드는 여행 지도")
                                .font(.system(size: 14))
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Spacer()
                    }

                    DemoBoardView()
                        .frame(maxWidth: 360)
                        .aspectRatio(0.68, contentMode: .fit)
                        .shadow(color: MRColor.ink.opacity(0.08), radius: 18, y: 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("찍어둔 사진이,\n하루의 여행 보드가 됩니다.")
                            .font(.system(size: 29, weight: .bold))
                            .foregroundStyle(MRColor.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("기록 시작도, 백그라운드 위치 추적도 필요 없습니다. 사진의 날짜와 장소만 기기 안에서 읽습니다.")
                            .font(.system(size: 15))
                            .foregroundStyle(MRColor.secondaryText)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 12) {
                        FeatureRow(symbol: "mappin", title: "사진 속 장소 자동 발견")
                        FeatureRow(symbol: "point.topleft.down.to.point.bottomright.curvepath", title: "시간순 직선 실 연결")
                        FeatureRow(symbol: "square.and.arrow.up", title: "고화질 포토보드 저장과 공유")
                    }

                    Button("내 사진으로 만들어보기") {
                        showingPermission = true
                    }
                    .buttonStyle(MRPrimaryButtonStyle())

                    Text("사진과 위치정보는 서버로 전송하지 않습니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(MRColor.secondaryText)
                }
                .padding(.horizontal, MRSpacing.screen)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingPermission) {
            PermissionExplainerView(
                isRequesting: isRequesting,
                onContinue: {
                    isRequesting = true
                    Task {
                        await photoLibrary.requestAccess()
                        isRequesting = false
                        showingPermission = false
                        onComplete()
                    }
                },
                onContinueWithoutAccess: {
                    showingPermission = false
                    onComplete()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MRColor.accent)
                .frame(width: 36, height: 36)
                .background(MRColor.accentSoft)
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Spacer()
        }
    }
}

struct PermissionExplainerView: View {
    let isRequesting: Bool
    let onContinue: () -> Void
    let onContinueWithoutAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("사진의 날짜와 장소를 읽습니다")
                    .font(.system(size: 23, weight: .bold))
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(["photo", "calendar", "mappin.and.ellipse"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(MRColor.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(MRColor.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("사진 원본을 업로드하지 않습니다", systemImage: "checkmark.circle")
                Label("현재 위치 권한을 요청하지 않습니다", systemImage: "checkmark.circle")
                Label("제한된 사진 접근도 사용할 수 있습니다", systemImage: "checkmark.circle")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(MRColor.primaryText)

            Spacer(minLength: 0)

            Button(action: onContinue) {
                if isRequesting {
                    ProgressView().tint(MRColor.paper)
                } else {
                    Text("사진 접근 계속")
                }
            }
            .buttonStyle(MRPrimaryButtonStyle())
            .disabled(isRequesting)

            Button("나중에 설정") {
                onContinueWithoutAccess()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MRColor.secondaryText)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(MRColor.background)
    }
}

private struct DemoBoardView: View {
    private let model = DemoBoardFactory.makeModel()

    var body: some View {
        BoardCanvasView(model: model, watermark: false)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

@MainActor
private enum DemoBoardFactory {
    static func makeModel() -> BoardRenderModel {
        let ids = [
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        ]
        let date = Date(timeIntervalSince1970: 1_781_568_000)
        let titles = ["해운대", "흰여울길", "광안리"]
        let symbols = ["water.waves", "house.fill", "moon.stars.fill"]
        var images: [String: UIImage] = [:]
        var places: [BoardPlace] = []

        for index in ids.indices {
            let assetIDs = (1...3).map { "onboarding-\(index)-\($0)" }
            for assetID in assetIDs {
                images[assetID] = demoPhoto(symbol: symbols[index], variant: index)
            }
            places.append(
                BoardPlace(
                    id: ids[index],
                    title: titles[index],
                    subtitle: nil,
                    administrativeArea: "부산광역시",
                    locality: titles[index],
                    latitude: 35.16 + Double(index) * 0.01,
                    longitude: 129.04 + Double(index) * 0.01,
                    startDate: date.addingTimeInterval(Double(index) * 7_200),
                    endDate: date.addingTimeInterval(Double(index) * 7_200 + 2_400),
                    assetIdentifiers: assetIDs,
                    representativeAssetIdentifier: assetIDs[0],
                    isHidden: false
                )
            )
        }

        return BoardRenderModel(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            title: "부산 하루 여행",
            date: date,
            places: places,
            template: .ribbon,
            mapImage: demoMap(),
            normalizedPoints: [:],
            photoImages: images
        )
    }

    private static func demoPhoto(symbol: String, variant: Int) -> UIImage {
        let size = CGSize(width: 500, height: 420)
        return UIGraphicsImageRenderer(size: size).image { context in
            let palette = [
                UIColor(red: 0.79, green: 0.34, blue: 0.26, alpha: 1),
                UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 1),
                UIColor(red: 0.78, green: 0.73, blue: 0.64, alpha: 1)
            ]
            palette[variant % palette.count].setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.16).setFill()
            UIBezierPath(ovalIn: CGRect(x: 80, y: 42, width: 340, height: 340)).fill()
            let configuration = UIImage.SymbolConfiguration(pointSize: 125, weight: .semibold)
            UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 187, y: 135, width: 126, height: 126))
        }
    }

    private static func demoMap() -> UIImage {
        let size = CGSize(width: 720, height: 1_080)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.94, green: 0.92, blue: 0.87, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.setStrokeColor(UIColor(red: 0.15, green: 0.14, blue: 0.12, alpha: 0.10).cgColor)
            cg.setLineWidth(3)
            for x in stride(from: 30, through: 690, by: 85) {
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x - 90, y: 1_080))
                cg.strokePath()
            }
            for y in stride(from: 60, through: 1_020, by: 100) {
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: 720, y: y + 45))
                cg.strokePath()
            }
        }
    }
}
