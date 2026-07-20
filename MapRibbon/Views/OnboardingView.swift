import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    let onComplete: () -> Void

    @State private var showingPermission = false
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                brandHeader

                VStack(alignment: .leading, spacing: 9) {
                    Text("찍어둔 사진이\n하루의 여행 보드가 됩니다.")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MRColor.primaryText)
                    Text("사진의 시간과 위치만 읽어 지도 위에 자동으로 엮습니다. 기록 시작이나 백그라운드 위치 추적은 필요 없습니다.")
                        .font(.body)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineSpacing(4)
                }

                OnboardingBoardPreview()
                    .aspectRatio(0.92, contentMode: .fit)
                    .frame(maxWidth: 390)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)

                VStack(spacing: 10) {
                    FeatureRow(symbol: "photo.stack", title: "사진 속 장소 자동 발견", detail: "서버 전송 없이 기기 안에서 처리")
                    FeatureRow(symbol: "point.topleft.down.to.point.bottomright.curvepath", title: "시간순 리본 연결", detail: "정확한 GPS 경로 대신 하루의 흐름을 표현")
                    FeatureRow(symbol: "square.and.arrow.up", title: "한 장으로 저장과 공유", detail: "스토리·피드·포스터 비율 지원")
                }

                Label("사진 원본과 위치정보는 서버로 전송하지 않습니다.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(MRColor.secondaryText)
                    .padding(.bottom, 96)
            }
            .padding(.horizontal, MRSpacing.screen)
            .padding(.top, 14)
        }
        .background(MRColor.background)
        .safeAreaInset(edge: .bottom) {
            Button("내 사진으로 만들어보기") { showingPermission = true }
                .buttonStyle(MRPrimaryButtonStyle())
                .padding(.horizontal, MRSpacing.screen)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingPermission) {
            PermissionExplainerView(
                isRequesting: isRequesting,
                onContinue: requestAccess,
                onContinueWithoutAccess: {
                    showingPermission = false
                    onComplete()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3.weight(.semibold))
                .foregroundStyle(MRColor.accent)
                .frame(width: 44, height: 44)
                .background(MRColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("MapRibbon").font(.title3.weight(.bold))
                Text("사진으로 만드는 여행 지도")
                    .font(.caption)
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
        }
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            await photoLibrary.requestAccess()
            isRequesting = false
            showingPermission = false
            onComplete()
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(MRColor.accent)
                .frame(width: 38, height: 38)
                .background(MRColor.accentSoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(MRColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct PermissionExplainerView: View {
    let isRequesting: Bool
    let onContinue: () -> Void
    let onContinueWithoutAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("사진의 날짜와 장소를 읽습니다")
                .font(.title2.weight(.bold))

            HStack(spacing: 10) {
                ForEach(["photo", "calendar", "mappin.and.ellipse"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(MRColor.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(MRColor.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                Label("사진 원본을 업로드하지 않습니다", systemImage: "checkmark.circle.fill")
                Label("현재 위치 권한을 요청하지 않습니다", systemImage: "checkmark.circle.fill")
                Label("제한된 사진 접근도 사용할 수 있습니다", systemImage: "checkmark.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(MRColor.primaryText)
            .symbolRenderingMode(.hierarchical)

            Spacer(minLength: 0)

            Button(action: onContinue) {
                if isRequesting { ProgressView().tint(.white) } else { Text("사진 접근 계속") }
            }
            .buttonStyle(MRPrimaryButtonStyle())
            .disabled(isRequesting)

            Button("나중에 설정", action: onContinueWithoutAccess)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(MRColor.background)
    }
}

@MainActor
private struct OnboardingBoardPreview: View {
    @State private var draft: BoardDraft

    init() {
        _draft = State(initialValue: BoardScreenshotFixture.makeDraft())
    }

    var body: some View {
        BoardCanvasView(model: draft.renderModel, watermark: false)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct DemoRope: View {
    let start: CGPoint
    let end: CGPoint
    let size: CGSize

    var body: some View {
        let p1 = CGPoint(x: start.x * size.width, y: start.y * size.height)
        let p2 = CGPoint(x: end.x * size.width, y: end.y * size.height)
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let length = sqrt(dx * dx + dy * dy)
        Image("RouteRopeRed")
            .resizable(capInsets: EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14), resizingMode: .tile)
            .frame(width: length, height: max(5, size.width * 0.018))
            .rotationEffect(.radians(Double(atan2(dy, dx))))
            .position(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
    }
}

private struct DemoPin: View {
    let asset: String
    let position: CGPoint
    let size: CGSize

    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(width: size.width * 0.065, height: size.width * 0.10)
            .position(x: position.x * size.width, y: position.y * size.height)
    }
}

private struct DemoPolaroid: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tint
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 9, weight: .bold))
                Text("사진 3장").font(.system(size: 7)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(.white)
        }
        .padding(4)
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }
}

private struct DemoCorkTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<110 {
                let x = CGFloat((index * 47) % 101) / 101 * size.width
                let y = CGFloat((index * 73) % 107) / 107 * size.height
                let radius = CGFloat(1 + index % 3)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)), with: .color(.black.opacity(0.08)))
            }
        }
    }
}

private struct DemoMapLines: View {
    var body: some View {
        Canvas { context, size in
            let line = Color(hex: 0xB8B1A3).opacity(0.46)
            for i in 0..<8 {
                var path = Path()
                let y = size.height * CGFloat(i + 1) / 9
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(to: CGPoint(x: size.width, y: y + CGFloat(i % 2) * 10 - 5), control1: CGPoint(x: size.width * 0.3, y: y - 12), control2: CGPoint(x: size.width * 0.7, y: y + 12))
                context.stroke(path, with: .color(line), lineWidth: 1)
            }
            for i in 0..<5 {
                let x = size.width * CGFloat(i + 1) / 6
                context.stroke(Path(CGRect(x: x, y: 0, width: 0.7, height: size.height)), with: .color(line.opacity(0.7)), lineWidth: 0.7)
            }
        }
    }
}
