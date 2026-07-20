import SwiftUI
import SwiftData
import Photos
import MapKit

private struct AtlasRegionDescriptor: Identifiable, Hashable {
    let key: String
    let name: String
    let latitude: Double
    let longitude: Double

    var id: String { key }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum AtlasCountry: String, CaseIterable, Identifiable {
    case korea
    case japan

    var id: String { rawValue }
    var title: String { self == .korea ? "한국" : "일본" }
    var fullTitle: String { self == .korea ? "대한민국" : "일본" }
    var total: Int { regions.count }

    var mapRegion: MKCoordinateRegion {
        switch self {
        case .korea:
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2, longitude: 127.8),
                span: MKCoordinateSpan(latitudeDelta: 7.4, longitudeDelta: 8.4)
            )
        case .japan:
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 137.2),
                span: MKCoordinateSpan(latitudeDelta: 16.5, longitudeDelta: 19.5)
            )
        }
    }

    fileprivate var regions: [AtlasRegionDescriptor] {
        switch self {
        case .korea:
            return [
                .init(key: "서울", name: "서울", latitude: 37.5665, longitude: 126.9780),
                .init(key: "부산", name: "부산", latitude: 35.1796, longitude: 129.0756),
                .init(key: "대구", name: "대구", latitude: 35.8714, longitude: 128.6014),
                .init(key: "인천", name: "인천", latitude: 37.4563, longitude: 126.7052),
                .init(key: "광주", name: "광주", latitude: 35.1595, longitude: 126.8526),
                .init(key: "대전", name: "대전", latitude: 36.3504, longitude: 127.3845),
                .init(key: "울산", name: "울산", latitude: 35.5384, longitude: 129.3114),
                .init(key: "세종", name: "세종", latitude: 36.4800, longitude: 127.2890),
                .init(key: "경기", name: "경기", latitude: 37.4138, longitude: 127.5183),
                .init(key: "강원", name: "강원", latitude: 37.8228, longitude: 128.1555),
                .init(key: "충북", name: "충북", latitude: 36.8635, longitude: 127.7298),
                .init(key: "충남", name: "충남", latitude: 36.5184, longitude: 126.8000),
                .init(key: "전북", name: "전북", latitude: 35.7175, longitude: 127.1530),
                .init(key: "전남", name: "전남", latitude: 34.8679, longitude: 126.9910),
                .init(key: "경북", name: "경북", latitude: 36.4919, longitude: 128.8889),
                .init(key: "경남", name: "경남", latitude: 35.4606, longitude: 128.2132),
                .init(key: "제주", name: "제주", latitude: 33.4996, longitude: 126.5312),
            ]
        case .japan:
            return [
                .init(key: "일본:홋카이도", name: "홋카이도", latitude: 43.2203, longitude: 142.8635),
                .init(key: "일본:도호쿠", name: "도호쿠", latitude: 39.7036, longitude: 140.1024),
                .init(key: "일본:간토", name: "간토", latitude: 35.6762, longitude: 139.6503),
                .init(key: "일본:주부", name: "주부", latitude: 36.6953, longitude: 137.2113),
                .init(key: "일본:간사이", name: "간사이", latitude: 34.6937, longitude: 135.5023),
                .init(key: "일본:주고쿠", name: "주고쿠", latitude: 34.3853, longitude: 132.4553),
                .init(key: "일본:시코쿠", name: "시코쿠", latitude: 33.8416, longitude: 132.7657),
                .init(key: "일본:규슈", name: "규슈", latitude: 33.5902, longitude: 130.4017),
            ]
        }
    }
}

private struct AtlasVisit: Identifiable {
    let id: String
    let title: String
    let date: Date?
    let photoCount: Int
    let coordinate: CLLocationCoordinate2D
    let country: AtlasCountry
}

struct AtlasView: View {
    @Query(sort: \SavedBoard.createdAt, order: .reverse) private var boards: [SavedBoard]
    @State private var country: AtlasCountry
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedVisitID: String?

    init(initialCountry: AtlasCountry = .korea) {
        _country = State(initialValue: initialCountry)
        _cameraPosition = State(initialValue: .region(initialCountry.mapRegion))
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

    private var visibleRegions: [AtlasRegionDescriptor] { country.regions }
    private var visitedCount: Int { visibleRegions.filter { visited.contains($0.key) }.count }

    private var decodedVisits: [AtlasVisit] {
        boards.flatMap { board -> [AtlasVisit] in
            guard let payload = try? JSONDecoder().decode(BoardArchivePayload.self, from: board.payloadData) else {
                return []
            }
            let boardCountry = resolvedCountry(from: board.regionKeys)
            return payload.places.compactMap { place in
                guard !place.isHidden, CLLocationCoordinate2DIsValid(place.coordinate) else { return nil }
                let resolvedCountry = boardCountry ?? fallbackCountry(for: place.coordinate)
                guard let resolvedCountry else { return nil }
                return AtlasVisit(
                    id: "\(board.id.uuidString)-\(place.id.uuidString)",
                    title: place.title,
                    date: board.date,
                    photoCount: place.photoCount,
                    coordinate: place.coordinate,
                    country: resolvedCountry
                )
            }
        }
    }

    private var mapVisits: [AtlasVisit] {
        let actual = decodedVisits.filter { $0.country == country }
        if !actual.isEmpty { return actual }
        return visibleRegions
            .filter { visited.contains($0.key) }
            .map {
                AtlasVisit(
                    id: "region-\($0.key)",
                    title: $0.name,
                    date: nil,
                    photoCount: 0,
                    coordinate: $0.coordinate,
                    country: country
                )
            }
    }

    private var selectedVisit: AtlasVisit? {
        guard let selectedVisitID else { return nil }
        return mapVisits.first { $0.id == selectedVisitID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("아틀라스").font(.largeTitle.weight(.bold))
                        Text("저장한 보드의 실제 촬영 위치를 지도에서 확인합니다")
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

                ActualAtlasMap(
                    country: country,
                    visits: mapVisits,
                    cameraPosition: $cameraPosition,
                    selectedVisitID: $selectedVisitID
                )
                .frame(height: 410)

                if let selectedVisit {
                    AtlasVisitDetail(visit: selectedVisit)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 13) {
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
                        ForEach(visibleRegions) { region in
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
        .animation(.easeOut(duration: 0.18), value: selectedVisitID)
        .onChange(of: country) { _, newCountry in
            selectedVisitID = nil
            withAnimation(.easeOut(duration: 0.28)) {
                cameraPosition = .region(newCountry.mapRegion)
            }
        }
    }

    private func resolvedCountry(from regionKeys: [String]) -> AtlasCountry? {
        let hasJapan = regionKeys.contains { $0.hasPrefix("일본:") }
        let hasKorea = regionKeys.contains { !$0.hasPrefix("일본:") }
        if hasJapan && !hasKorea { return .japan }
        if hasKorea && !hasJapan { return .korea }
        return nil
    }

    private func fallbackCountry(for coordinate: CLLocationCoordinate2D) -> AtlasCountry? {
        if coordinate.latitude >= 33.0, coordinate.latitude <= 39.5,
           coordinate.longitude >= 124.0, coordinate.longitude <= 130.2 {
            return .korea
        }
        if coordinate.latitude >= 24.0, coordinate.latitude <= 46.5,
           coordinate.longitude >= 122.0, coordinate.longitude <= 146.5 {
            return .japan
        }
        return nil
    }
}

private struct ActualAtlasMap: View {
    let country: AtlasCountry
    let visits: [AtlasVisit]
    @Binding var cameraPosition: MapCameraPosition
    @Binding var selectedVisitID: String?

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            ForEach(visits) { visit in
                Annotation(visit.title, coordinate: visit.coordinate, anchor: .bottom) {
                    Button {
                        selectedVisitID = visit.id
                    } label: {
                        AtlasMapPin(isSelected: selectedVisitID == visit.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(visit.title) 방문 위치")
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay(alignment: .topLeading) {
            HStack(spacing: 7) {
                Image(systemName: "camera.fill")
                Text(visits.isEmpty ? "저장된 촬영 위치 없음" : "촬영 위치 \(visits.count)곳")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(MRColor.primaryText)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                selectedVisitID = nil
                withAnimation(.easeOut(duration: 0.24)) {
                    cameraPosition = .region(country.mapRegion)
                }
            } label: {
                Image(systemName: "scope")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MRColor.primaryText)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel("지도 위치 초기화")
        }
        .overlay {
            if visits.isEmpty {
                ContentUnavailableView(
                    "아직 촬영 위치가 없습니다",
                    systemImage: "mappin.slash",
                    description: Text("여행 보드를 저장하면 실제 사진 위치가 지도에 표시됩니다.")
                )
                .padding(24)
                .background(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MRColor.border.opacity(0.7), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.08), radius: 13, y: 7)
        .accessibilityLabel("\(country.fullTitle) 실제 촬영 위치 지도")
    }
}

private struct AtlasMapPin: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(MRColor.accent)
                .frame(width: isSelected ? 38 : 32, height: isSelected ? 38 : 32)
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
            Circle()
                .stroke(.white.opacity(0.95), lineWidth: 2.5)
                .frame(width: isSelected ? 38 : 32, height: isSelected ? 38 : 32)
            Image(systemName: "camera.fill")
                .font(.system(size: isSelected ? 15 : 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

private struct AtlasVisitDetail: View {
    let visit: AtlasVisit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.headline.weight(.semibold))
                .foregroundStyle(MRColor.accent)
                .frame(width: 42, height: 42)
                .background(MRColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(visit.title)
                    .font(.headline)
                    .lineLimit(1)
                if let date = visit.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(MRColor.secondaryText)
                } else {
                    Text("방문 지역 대표 위치")
                        .font(.caption)
                        .foregroundStyle(MRColor.secondaryText)
                }
            }
            Spacer()
            if visit.photoCount > 0 {
                Text("\(visit.photoCount)장")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(MRColor.accent)
            }
        }
        .mrCard(padding: 14, shadow: false)
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
