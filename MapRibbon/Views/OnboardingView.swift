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

                VStack(alignment: .leading, spacing: 10) {
                    Text("찍어둔 사진이\n하루의 여행 보드가 됩니다.")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MRColor.primaryText)
                    Text("사진에 남은 시간과 장소를 읽어 한 장의 지도 기록으로 엮습니다.")
                        .font(.body)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineSpacing(4)
                }

                OnboardingBoardPreview()
                    .aspectRatio(0.84, contentMode: .fit)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 11)

                VStack(alignment: .leading, spacing: 13) {
                    OnboardingFact(symbol: "record.circle", text: "기록 시작이 필요하지 않습니다")
                    OnboardingFact(symbol: "location.slash", text: "현재 위치 권한을 요청하지 않습니다")
                    OnboardingFact(symbol: "iphone", text: "사진과 위치정보는 기기 안에서만 처리합니다")
                }
                .padding(.horizontal, 2)

                Text("정확한 이동 경로를 추적하지 않고 사진의 순서와 장소만 표현합니다.")
                    .font(.footnote)
                    .foregroundStyle(MRColor.tertiaryText)
                    .padding(.bottom, 104)
            }
            .padding(.horizontal, MRSpacing.screen)
            .padding(.top, 14)
        }
        .background(MRColor.background)
        .safeAreaInset(edge: .bottom) {
            Button("사진에서 하루 찾기") { showingPermission = true }
                .buttonStyle(MRPrimaryButtonStyle())
                .padding(.horizontal, MRSpacing.screen)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.regularMaterial)
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
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(MRColor.accent)
                .frame(width: 44, height: 44)
                .background(MRColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("MapRibbon").font(.title3.weight(.bold))
                Text("사진으로 엮는 여행 기록")
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

private struct OnboardingFact: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MRColor.primaryText)
        } icon: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(MRColor.mapTeal)
                .frame(width: 28)
        }
        .frame(minHeight: 34)
    }
}

private struct PermissionExplainerView: View {
    let isRequesting: Bool
    let onContinue: () -> Void
    let onContinueWithoutAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("사진의 날짜와 장소를 읽습니다")
                    .font(.title2.weight(.bold))
                Text("보드에 사용할 사진만 선택해서 허용해도 됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
            }

            HStack(spacing: 10) {
                permissionSymbol("photo")
                Image(systemName: "arrow.right")
                    .foregroundStyle(MRColor.tertiaryText)
                permissionSymbol("calendar")
                Image(systemName: "arrow.right")
                    .foregroundStyle(MRColor.tertiaryText)
                permissionSymbol("map")
            }

            VStack(alignment: .leading, spacing: 13) {
                Label("사진 원본을 업로드하지 않습니다", systemImage: "checkmark.circle.fill")
                Label("현재 위치를 추적하지 않습니다", systemImage: "checkmark.circle.fill")
                Label("제한된 사진 접근을 지원합니다", systemImage: "checkmark.circle.fill")
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
                .frame(minHeight: 44)
        }
        .padding(24)
        .background(MRColor.background)
    }

    private func permissionSymbol(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(MRColor.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(MRColor.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
            }
            .accessibilityHidden(true)
    }
}
