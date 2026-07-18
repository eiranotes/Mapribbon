import SwiftUI
import SwiftData
import Photos

struct AtlasView: View {
    @Query(sort: \SavedBoard.createdAt, order: .reverse) private var boards: [SavedBoard]

    private var visited: Set<String> {
        Set(boards.flatMap(\.regionKeys))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("아틀라스")
                            .font(.system(size: 30, weight: .bold))
                        Text("보드를 만들수록 방문 지역이 채워집니다")
                            .font(.system(size: 14))
                            .foregroundStyle(MRColor.secondaryText)
                    }
                    Spacer()
                }
                .padding(.top, 18)

                VStack(spacing: 16) {
                    KoreaConstellationView(visited: visited)
                        .frame(height: 360)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("대한민국")
                                .font(.system(size: 18, weight: .bold))
                            Text("\(visited.count) / 17 지역 방문")
                                .font(.system(size: 13))
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Spacer()
                        Text("\(Int(Double(visited.count) / 17.0 * 100))%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(MRColor.accent)
                    }

                    ProgressView(value: Double(visited.count), total: 17)
                        .tint(MRColor.accent)
                }
                .mrCard()

                VStack(spacing: 12) {
                    MRSectionHeader(title: "지역", subtitle: "최근 저장한 보드 기준")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(KoreaRegion.all) { region in
                            VStack(spacing: 7) {
                                Image(systemName: visited.contains(region.key) ? "mappin.circle.fill" : "circle.dashed")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(visited.contains(region.key) ? MRColor.accent : MRColor.border)
                                Text(region.shortName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(visited.contains(region.key) ? MRColor.primaryText : MRColor.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 82)
                            .background(MRColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(MRColor.border) }
                        }
                    }
                }
            }
            .padding(.horizontal, MRSpacing.screen)
            .padding(.bottom, 36)
        }
        .background(MRColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct KoreaConstellationView: View {
    let visited: Set<String>

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    let ordered = KoreaRegion.all.filter { $0.key != "제주" }
                    guard let first = ordered.first else { return }
                    path.move(to: point(first, size: proxy.size))
                    for region in ordered.dropFirst() {
                        path.addLine(to: point(region, size: proxy.size))
                    }
                }
                .stroke(MRColor.border.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))

                ForEach(KoreaRegion.all) { region in
                    VStack(spacing: 3) {
                        Circle()
                            .fill(visited.contains(region.key) ? MRColor.accent : MRColor.secondarySurface)
                            .overlay { Circle().stroke(visited.contains(region.key) ? MRColor.accent : MRColor.border, lineWidth: 1) }
                            .frame(width: visited.contains(region.key) ? 19 : 15, height: visited.contains(region.key) ? 19 : 15)
                        Text(region.shortName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(visited.contains(region.key) ? MRColor.primaryText : MRColor.secondaryText)
                    }
                    .position(point(region, size: proxy.size))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(MRColor.secondarySurface.opacity(0.65))
            )
        }
    }

    private func point(_ region: KoreaRegion, size: CGSize) -> CGPoint {
        CGPoint(x: region.normalizedPoint.x * size.width, y: region.normalizedPoint.y * size.height)
    }
}

struct SettingsView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(StoreService.self) private var store
    @AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.story.rawValue
    @State private var showingPaywall = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MRColor.accent)
                        .frame(width: 44, height: 44)
                        .background(MRColor.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MapRibbon")
                            .font(.system(size: 18, weight: .bold))
                        Text("사진으로 만드는 여행 지도")
                            .font(.system(size: 13))
                            .foregroundStyle(MRColor.secondaryText)
                    }
                }
            }

            Section("사진") {
                HStack {
                    Label("사진 접근", systemImage: "photo")
                    Spacer()
                    Text(permissionText)
                        .foregroundStyle(MRColor.secondaryText)
                }
                if photoLibrary.isLimited {
                    Button("접근 가능한 사진 추가") { photoLibrary.showLimitedLibraryPicker() }
                }
                Button("사진 다시 확인") {
                    Task { await photoLibrary.scanRecentDays() }
                }
            }

            Section("내보내기") {
                Picker("기본 비율", selection: $defaultFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.title).tag(format.rawValue)
                    }
                }
            }

            Section("구매") {
                if store.isUnlocked {
                    Label("전체 기능 잠금 해제됨", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(MRColor.success)
                } else {
                    Button("전체 기능 잠금 해제") { showingPaywall = true }
                }
                Button("구매 복원") { Task { await store.restore() } }
            }

            Section("개인정보") {
                Label("계정 없음", systemImage: "person.crop.circle.badge.xmark")
                Label("백그라운드 위치 추적 없음", systemImage: "location.slash")
                Label("사진 원본 업로드 없음", systemImage: "icloud.slash")
            }

            Section {
                HStack {
                    Text("버전")
                    Spacer()
                    Text("0.1.0 MVP").foregroundStyle(MRColor.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MRColor.background)
        .navigationTitle("설정")
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .alert("MapRibbon", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var permissionText: String {
        switch photoLibrary.authorizationStatus {
        case .authorized: return "전체 허용"
        case .limited: return "선택한 사진"
        case .denied, .restricted: return "허용 안 함"
        case .notDetermined: return "미설정"
        @unknown default: return "알 수 없음"
        }
    }
}

struct PaywallView: View {
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MRColor.secondaryText)
                        .frame(width: 38, height: 38)
                        .background(MRColor.secondarySurface)
                        .clipShape(Circle())
                }
            }

            Image(systemName: "map.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(MRColor.accent)
                .frame(width: 92, height: 92)
                .background(MRColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 8) {
                Text("MapRibbon 전체 기능")
                    .font(.system(size: 26, weight: .bold))
                Text("구독 없이 한 번 구매하면 계속 사용할 수 있습니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(MRColor.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                PaywallRow(symbol: "square.stack.3d.up", text: "4개 보드 템플릿")
                PaywallRow(symbol: "photo.badge.checkmark", text: "고해상도 저장과 워터마크 제거")
                PaywallRow(symbol: "clock.arrow.circlepath", text: "과거 날짜와 보드 무제한")
                PaywallRow(symbol: "map", text: "Memory Atlas 전체 기능")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button {
                Task {
                    await store.purchaseLifetime()
                    if store.isUnlocked { dismiss() }
                }
            } label: {
                if store.isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let price = store.lifetimeProduct?.displayPrice {
                    Text("영구 잠금 해제 · \(price)")
                } else {
                    Text("영구 잠금 해제")
                }
                }
            }
            .buttonStyle(MRPrimaryButtonStyle())

            Button("구매 복원") { Task { await store.restore() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MRColor.secondaryText)
        }
        .padding(24)
        .background(MRColor.background)
    }
}

private struct PaywallRow: View {
    let symbol: String
    let text: String
    var body: some View {
        Label {
            Text(text).font(.system(size: 15, weight: .medium))
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(MRColor.accent)
                .frame(width: 28)
        }
    }
}
