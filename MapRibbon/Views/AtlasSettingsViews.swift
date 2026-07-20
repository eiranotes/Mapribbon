import SwiftUI
import SwiftData
import Photos

enum AtlasCountry: String, CaseIterable, Identifiable {
    case korea
    case japan

    var id: String { rawValue }
    var title: String { self == .korea ? "한국" : "일본" }
    var fullTitle: String { self == .korea ? "대한민국" : "일본" }
    var total: Int { self == .korea ? KoreaRegion.all.count : JapanAtlasRegion.all.count }
}

private struct JapanAtlasRegion: Identifiable, Hashable {
    let key: String
    let shortName: String
    let normalizedPoint: CGPoint
    var id: String { key }

    static let all: [JapanAtlasRegion] = [
        .init(key: "일본:홋카이도", shortName: "홋카이도", normalizedPoint: CGPoint(x: 0.72, y: 0.15)),
        .init(key: "일본:도호쿠", shortName: "도호쿠", normalizedPoint: CGPoint(x: 0.59, y: 0.31)),
        .init(key: "일본:간토", shortName: "간토", normalizedPoint: CGPoint(x: 0.58, y: 0.48)),
        .init(key: "일본:주부", shortName: "주부", normalizedPoint: CGPoint(x: 0.46, y: 0.51)),
        .init(key: "일본:간사이", shortName: "간사이", normalizedPoint: CGPoint(x: 0.36, y: 0.59)),
        .init(key: "일본:주고쿠", shortName: "주고쿠", normalizedPoint: CGPoint(x: 0.24, y: 0.64)),
        .init(key: "일본:시코쿠", shortName: "시코쿠", normalizedPoint: CGPoint(x: 0.31, y: 0.71)),
        .init(key: "일본:규슈", shortName: "규슈", normalizedPoint: CGPoint(x: 0.16, y: 0.78)),
    ]
}

struct AtlasView: View {
    @Query(sort: \SavedBoard.createdAt, order: .reverse) private var boards: [SavedBoard]
    @State private var country: AtlasCountry

    init(initialCountry: AtlasCountry = .korea) {
        _country = State(initialValue: initialCountry)
    }

    private var visited: Set<String> {
        var keys = Set(boards.flatMap(\.regionKeys))
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--screenshot-atlas") {
            keys.formUnion(["서울", "경기", "강원", "부산", "제주"])
        }
        if arguments.contains("--screenshot-atlas-japan") {
            keys.formUnion(["일본:간토", "일본:간사이", "일본:주부", "일본:규슈"])
        }
        return keys
    }

    private var visibleRegions: [(key: String, name: String, point: CGPoint)] {
        switch country {
        case .korea:
            return KoreaRegion.all.map { ($0.key, $0.shortName, $0.normalizedPoint) }
        case .japan:
            return JapanAtlasRegion.all.map { ($0.key, $0.shortName, $0.normalizedPoint) }
        }
    }

    private var visitedCount: Int { visibleRegions.filter { visited.contains($0.key) }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("아틀라스").font(.largeTitle.weight(.bold))
                        Text("여행 보드를 저장할수록 두 나라의 지도가 채워집니다")
                            .font(.subheadline)
                            .foregroundStyle(MRColor.secondaryText)
                    }
                    Spacer()
                }
                .padding(.top, 14)

                Picker("국가", selection: $country) {
                    ForEach(AtlasCountry.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 16) {
                    CountryAtlasMap(country: country, regions: visibleRegions, visited: visited)
                        .frame(height: 390)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(country.fullTitle).font(.title3.weight(.bold))
                            Text("\(visitedCount) / \(country.total) 지역 방문")
                                .font(.footnote)
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Spacer()
                        Text("\(Int(Double(visitedCount) / Double(max(1, country.total)) * 100))%")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(MRColor.accent)
                    }
                    ProgressView(value: Double(visitedCount), total: Double(country.total)).tint(MRColor.accent)
                }
                .mrCard()

                VStack(spacing: 12) {
                    MRSectionHeader(title: "지역", subtitle: "저장한 보드의 행정 지역 기준")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(visibleRegions, id: \.key) { region in
                            HStack(spacing: 9) {
                                Image(systemName: visited.contains(region.key) ? "mappin.circle.fill" : "circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(visited.contains(region.key) ? MRColor.accent : MRColor.border)
                                Text(region.name)
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
        .animation(.easeOut(duration: 0.18), value: country)
    }
}

private struct CountryAtlasMap: View {
    let country: AtlasCountry
    let regions: [(key: String, name: String, point: CGPoint)]
    let visited: Set<String>

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0xF2EBDD))
                AtlasPaperTexture().clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                CountrySilhouette(country: country)
                    .fill(Color(hex: 0xD9D1C1))
                    .overlay { CountrySilhouette(country: country).stroke(Color(hex: 0x9E9586).opacity(0.85), lineWidth: 1.2) }
                    .padding(country == .korea ? 38 : 28)
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 3)

                ForEach(regions, id: \.key) { region in
                    VStack(spacing: 3) {
                        Circle()
                            .fill(visited.contains(region.key) ? MRColor.accent : Color.white.opacity(0.88))
                            .overlay { Circle().stroke(visited.contains(region.key) ? MRColor.accent : Color(hex: 0xAFA697), lineWidth: 1) }
                            .frame(width: visited.contains(region.key) ? 20 : 13, height: visited.contains(region.key) ? 20 : 13)
                            .shadow(color: visited.contains(region.key) ? MRColor.accent.opacity(0.22) : .clear, radius: 5)
                        Text(region.name)
                            .font(.system(size: country == .korea ? 8.5 : 8, weight: .semibold))
                            .foregroundStyle(visited.contains(region.key) ? MRColor.ink : MRColor.secondaryText)
                    }
                    .position(x: region.point.x * proxy.size.width, y: region.point.y * proxy.size.height)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(country.fullTitle) 방문 지역 지도")
    }
}

private struct CountrySilhouette: Shape {
    let country: AtlasCountry

    func path(in rect: CGRect) -> Path {
        switch country {
        case .korea: return koreaPath(in: rect)
        case .japan: return japanPath(in: rect)
        }
    }

    private func koreaPath(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var path = Path()
        path.move(to: p(0.48, 0.02))
        path.addCurve(to: p(0.68, 0.18), control1: p(0.60, 0.03), control2: p(0.69, 0.09))
        path.addCurve(to: p(0.73, 0.42), control1: p(0.72, 0.25), control2: p(0.77, 0.34))
        path.addCurve(to: p(0.64, 0.62), control1: p(0.74, 0.50), control2: p(0.68, 0.57))
        path.addCurve(to: p(0.57, 0.83), control1: p(0.63, 0.72), control2: p(0.62, 0.78))
        path.addCurve(to: p(0.44, 0.91), control1: p(0.53, 0.89), control2: p(0.49, 0.93))
        path.addCurve(to: p(0.31, 0.78), control1: p(0.38, 0.90), control2: p(0.31, 0.86))
        path.addCurve(to: p(0.25, 0.55), control1: p(0.26, 0.70), control2: p(0.22, 0.64))
        path.addCurve(to: p(0.31, 0.36), control1: p(0.25, 0.47), control2: p(0.28, 0.41))
        path.addCurve(to: p(0.30, 0.17), control1: p(0.35, 0.29), control2: p(0.28, 0.23))
        path.addCurve(to: p(0.48, 0.02), control1: p(0.34, 0.09), control2: p(0.41, 0.04))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.95, width: rect.width * 0.23, height: rect.height * 0.055))
        return path
    }

    private func japanPath(in rect: CGRect) -> Path {
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ angle: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y, width: rect.width * w, height: rect.height * h))
                .applying(CGAffineTransform(translationX: -(rect.midX), y: -(rect.midY)).rotated(by: angle).translatedBy(x: rect.midX, y: rect.midY))
        }
        var path = Path()
        path.addPath(ellipse(0.62, 0.03, 0.25, 0.17, -0.22))
        path.addPath(ellipse(0.48, 0.18, 0.18, 0.30, -0.18))
        path.addPath(ellipse(0.37, 0.39, 0.18, 0.36, -0.38))
        path.addPath(ellipse(0.24, 0.60, 0.22, 0.18, -0.22))
        path.addPath(ellipse(0.20, 0.69, 0.12, 0.11, 0.12))
        path.addPath(ellipse(0.08, 0.73, 0.15, 0.22, 0.20))
        return path
    }
}

private struct AtlasPaperTexture: View {
    var body: some View {
        Canvas { context, size in
            let ink = Color(hex: 0xC9C0B1).opacity(0.35)
            for index in 0..<11 {
                let y = size.height * CGFloat(index + 1) / 12
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(to: CGPoint(x: size.width, y: y + CGFloat(index % 3) * 8 - 8), control1: CGPoint(x: size.width * 0.30, y: y - 12), control2: CGPoint(x: size.width * 0.70, y: y + 13))
                context.stroke(path, with: .color(ink), lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SettingsView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(StoreService.self) private var store
    @AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.poster.rawValue
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
