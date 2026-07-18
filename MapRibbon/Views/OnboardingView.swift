import SwiftUI
import Photos

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
                        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

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
                        FeatureRow(symbol: "point.topleft.down.to.point.bottomright.curvepath", title: "시간순 리본 연결")
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
                    ProgressView().tint(.white)
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
    private let points = [
        CGPoint(x: 0.20, y: 0.64),
        CGPoint(x: 0.37, y: 0.43),
        CGPoint(x: 0.67, y: 0.50),
        CGPoint(x: 0.77, y: 0.28)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: 0xEAE4D8))

                MapPaperPattern()

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x * proxy.size.width, y: first.y * proxy.size.height))
                    for point in points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * proxy.size.width, y: point.y * proxy.size.height))
                    }
                }
                .stroke(MRColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 7]))

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(MRColor.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Text("\(index + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                        .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
                }

                SamplePhotoCard(symbol: "building.2", tint: Color(hex: 0xA9C7CF))
                    .frame(width: proxy.size.width * 0.34, height: proxy.size.height * 0.19)
                    .rotationEffect(.degrees(-4))
                    .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.25)

                SamplePhotoCard(symbol: "ferry", tint: Color(hex: 0x7AA9BE))
                    .frame(width: proxy.size.width * 0.32, height: proxy.size.height * 0.18)
                    .rotationEffect(.degrees(4))
                    .position(x: proxy.size.width * 0.70, y: proxy.size.height * 0.70)

                VStack(alignment: .leading, spacing: 3) {
                    Text("BUSAN · DAY 1")
                        .font(.system(size: 11, weight: .semibold))
                    Text("부산 하루 여행")
                        .font(.system(size: 24, weight: .bold))
                }
                .foregroundStyle(MRColor.ink)
                .position(x: proxy.size.width * 0.38, y: proxy.size.height * 0.10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private struct MapPaperPattern: View {
    var body: some View {
        Canvas { context, size in
            let line = Color(hex: 0xCEC6B9).opacity(0.55)
            for i in 0..<9 {
                var path = Path()
                let y = size.height * CGFloat(i + 1) / 10
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width, y: y + CGFloat((i % 2) * 8 - 4)),
                    control1: CGPoint(x: size.width * 0.35, y: y - 14),
                    control2: CGPoint(x: size.width * 0.65, y: y + 14)
                )
                context.stroke(path, with: .color(line), lineWidth: 1)
            }
        }
    }
}

private struct SamplePhotoCard: View {
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tint
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Rectangle().fill(.white).frame(height: 16)
        }
        .padding(5)
        .background(.white)
        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
    }
}
