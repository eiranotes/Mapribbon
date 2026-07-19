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
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("아틀라스").font(.largeTitle.weight(.bold))
                        Text("보드를 저장할수록 방문 지역이 채워집니다")
                            .font(.subheadline)
                            .foregroundStyle(MRColor.secondaryText)
                    }
                    Spacer()
                }
                .padding(.top, 14)

                VStack(spacing: 16) {
                    KoreaPaperMapView(visited: visited)
                        .frame(height: 360)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("대한민국").font(.title3.weight(.bold))
                            Text("\(visited.count) / 17 지역 방문")
                                .font(.footnote)
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Spacer()
                        Text("\(Int(Double(visited.count) / 17.0 * 100))%")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(MRColor.accent)
                    }

                    ProgressView(value: Double(visited.count), total: 17)
                        .tint(MRColor.accent)

                    if visited.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(MRColor.accent)
                            Text("보드 탭에서 첫 여행을 만들면 이 지도가 채워집니다.")
                                .font(.footnote)
                                .foregroundStyle(MRColor.secondaryText)
                            Spacer()
                        }
                        .padding(12)
                        .background(MRColor.accentSoft.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
                .mrCard()

                VStack(spacing: 12) {
                    MRSectionHeader(title: "지역", subtitle: "최근 저장한 보드 기준")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(KoreaRegion.all) { region in
                            HStack(spacing: 9) {
                                Image(systemName: visited.contains(region.key) ? "mappin.circle.fill" : "circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(visited.contains(region.key) ? MRColor.accent : MRColor.border)
                                Text(region.shortName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(visited.contains(region.key) ? MRColor.primaryText : MRColor.secondaryText)
                                Spacer()
                            }
                            .padding(.horizontal, 13)
                            .frame(height: 50)
                            .background(MRColor.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 11).stroke(MRColor.border.opacity(0.55), lineWidth: 0.7) }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, MRSpacing.screen)
        }
        .background(MRColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct KoreaPaperMapView: View {
    let visited: Set<String>

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: 0xF2ECDD))
                AtlasPaperLines()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                ForEach(KoreaRegion.all) { region in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(visited.contains(region.key) ? MRColor.accent : Color.white.opacity(0.84))
                            .overlay {
                                Circle().stroke(visited.contains(region.key) ? MRColor.accent : Color(hex: 0xBDB5A7), lineWidth: 1)
                            }
                            .frame(width: visited.contains(region.key) ? 22 : 16, height: visited.contains(region.key) ? 22 : 16)
                            .shadow(color: visited.contains(region.key) ? MRColor.accent.opacity(0.20) : .clear, radius: 6)
                        Text(region.shortName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(visited.contains(region.key) ? MRColor.ink : MRColor.secondaryText)
                    }
                    .position(
                        x: region.normalizedPoint.x * proxy.size.width,
                        y: region.normalizedPoint.y * proxy.size.height
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("대한민국 방문 지역 지도")
        .accessibilityValue("17개 지역 중 \(visited.count)개 방문")
    }
}

private struct AtlasPaperLines: View {
    var body: some View {
        Canvas { context, size in
            let road = Color(hex: 0xCFC6B8).opacity(0.42)
            for i in 0..<9 {
                var path = Path()
                let y = size.height * CGFloat(i + 1) / 10
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(to: CGPoint(x: size.width, y: y + CGFloat(i % 2) * 12 - 6), control1: CGPoint(x: size.width * 0.25, y: y - 16), control2: CGPoint(x: size.width * 0.72, y: y + 16))
                context.stroke(path, with: .color(road), lineWidth: 1)
            }
            for i in 0..<6 {
                let x = size.width * CGFloat(i + 1) / 7
                context.stroke(Path(CGRect(x: x, y: 0, width: 0.8, height: size.height)), with: .color(road.opacity(0.7)), lineWidth: 0.7)
            }
        }
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
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MRColor.accent)
                        .frame(width: 44, height: 44)
                        .background(MRColor.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MapRibbon").font(.headline)
                        Text("사진으로 만드는 여행 지도")
                            .font(.caption)
                            .foregroundStyle(MRColor.secondaryText)
                    }
                }
            }

            Section("사진") {
                HStack {
                    Label("사진 접근", systemImage: "photo")
                    Spacer()
                    Text(permissionText).foregroundStyle(MRColor.secondaryText)
                }
                if photoLibrary.isLimited {
                    Button("접근 가능한 사진 추가") { photoLibrary.showLimitedLibraryPicker() }
                }
                Button("사진 다시 확인") { Task { await photoLibrary.scanRecentDays() } }
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
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(MRColor.secondaryText)
                            .frame(width: 40, height: 40)
                            .background(MRColor.secondarySurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(MRPressableStyle())
                }

                PremiumBoardSample()
                    .frame(height: 250)
                    .padding(.horizontal, 18)

                VStack(spacing: 8) {
                    Text("MapRibbon 전체 기능")
                        .font(.title.weight(.bold))
                    Text("한 번 구매하면 템플릿과 고해상도 저장을 계속 사용할 수 있습니다.")
                        .font(.subheadline)
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
                .padding(18)
                .background(MRColor.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    Task {
                        await store.purchaseLifetime()
                        if store.isUnlocked { dismiss() }
                    }
                } label: {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else if let price = store.lifetimeProduct?.displayPrice {
                        Text("영구 잠금 해제 · \(price)")
                    } else {
                        Text("영구 잠금 해제")
                    }
                }
                .buttonStyle(MRPrimaryButtonStyle())

                Button("구매 복원") { Task { await store.restore() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .padding(.bottom, 14)
            }
            .padding(20)
        }
        .background(MRColor.background)
    }
}

private struct PremiumBoardSample: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xA97845))
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF1EBDD)).padding(12)
                Image("RouteRopeRed")
                    .resizable(capInsets: EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14), resizingMode: .tile)
                    .frame(width: proxy.size.width * 0.58, height: 7)
                    .rotationEffect(.degrees(22))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                ForEach(Array(["building.columns.fill", "storefront.fill", "tree.fill"].enumerated()), id: \.offset) { index, symbol in
                    VStack(spacing: 0) {
                        ZStack {
                            [Color(hex: 0x6DA4C4), Color(hex: 0xD67C54), Color(hex: 0x6F9B70)][index]
                            Image(systemName: symbol).foregroundStyle(.white).font(.title3.weight(.semibold))
                        }
                        Rectangle().fill(.white).frame(height: 18)
                    }
                    .padding(4)
                    .background(.white)
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees([-5.0, 4.0, -2.0][index]))
                    .position(x: proxy.size.width * [0.28, 0.72, 0.44][index], y: proxy.size.height * [0.34, 0.53, 0.77][index])
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PaywallRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).font(.subheadline.weight(.medium))
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(MRColor.accent)
                .frame(width: 28)
        }
    }
}
