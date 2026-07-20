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
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2, longitude: 127.8),
                span: MKCoordinateSpan(latitudeDelta: 7.4, longitudeDelta: 8.4)
            )
        case .japan:
            MKCoordinateRegion(
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
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, MRSpacing.screen)
                    .padding(.bottom, 16)

                mapStage

                VStack(spacing: MRSpacing.section) {
                    if let selectedVisit {
                        AtlasVisitDrawer(visit: selectedVisit) {
                            selectedVisitID = nil
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        atlasSummary
                    }

                    visitedRegionStrip
                }
                .padding(.horizontal, MRSpacing.screen)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .background(MRScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.2), value: selectedVisitID)
        .onChange(of: country) { _, newCountry in
            selectedVisitID = nil
            withAnimation(.easeOut(duration: 0.25)) {
                cameraPosition = .region(newCountry.mapRegion)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                MREyebrow(text: "Atlas — 여행 수집 지도")
                Text("아틀라스")
                    .font(MRType.display(31))
                    .tracking(-0.4)
                Text("저장한 보드의 실제 촬영 위치")
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
                    .padding(.top, 2)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(MRColor.primaryText)
                    .frame(width: 44, height: 44)
                    .background(MRColor.elevatedSurface)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(MRColor.border.opacity(0.8), lineWidth: 0.7) }
            }
            .buttonStyle(MRPressableStyle())
        }
        .padding(.top, 16)
    }

    private var mapStage: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                ForEach(mapVisits) { visit in
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
            .frame(height: 455)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    withAnimation(.easeOut(duration: 0.24)) {
                        cameraPosition = .region(country.mapRegion)
                    }
                } label: {
                    Image(systemName: "scope")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(MRColor.primaryText)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.12), radius: 7, y: 3)
                }
                .buttonStyle(MRPressableStyle())
                .padding(14)
                .accessibilityLabel("지도 범위 초기화")
            }

            Picker("국가", selection: $country) {
                ForEach(AtlasCountry.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 184)
            .padding(6)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.13), radius: 9, y: 4)
            .padding(.top, 12)

            HStack(spacing: 7) {
                Image(systemName: "mappin.and.ellipse")
                Text("\(visitedCount)/\(country.total) 지역")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(MRColor.primaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(14)
            .allowsHitTesting(false)
        }
    }

    private var atlasSummary: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(MRColor.border.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                    .padding(6)
                Circle()
                    .trim(from: 0, to: Double(visitedCount) / Double(max(1, country.total)))
                    .stroke(MRColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6.5, 5]))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                Text("\(Int(Double(visitedCount) / Double(max(1, country.total)) * 100))%")
                    .font(MRType.plate(14, weight: .bold).monospacedDigit())
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 5) {
                Text(country.fullTitle)
                    .font(.title3.weight(.bold))
                Text(visitedCount == 0 ? "첫 여행 보드를 저장하면 지도에 핀이 생깁니다." : "방문한 지역 \(visitedCount)곳을 기록했습니다.")
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var visitedRegionStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            MRSectionHeader(title: "방문 지역", subtitle: "보드의 행정 지역 기준")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(visibleRegions) { region in
                        Label(
                            region.name,
                            systemImage: visited.contains(region.key) ? "mappin.circle.fill" : "circle"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(visited.contains(region.key) ? MRColor.mapTeal : MRColor.tertiaryText)
                        .padding(.horizontal, 11)
                        .frame(height: 38)
                        .background(MRColor.elevatedSurface)
                        .clipShape(Capsule())
                        .overlay { Capsule().stroke(MRColor.border.opacity(0.7), lineWidth: 0.7) }
                    }
                }
                .padding(.vertical, 2)
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

private struct AtlasMapPin: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: isSelected ? 38 : 32, height: isSelected ? 38 : 32)
                .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
            Circle()
                .fill(isSelected ? MRColor.accent : MRColor.mapTeal)
                .frame(width: isSelected ? 27 : 22, height: isSelected ? 27 : 22)
            Image(systemName: "camera.fill")
                .font(.system(size: isSelected ? 12 : 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(isSelected ? 1.06 : 1)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

private struct AtlasVisitDrawer: View {
    let visit: AtlasVisit
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("선택한 장소")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MRColor.accent)
                        .textCase(.uppercase)
                        .tracking(0.7)
                    Text(visit.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MRColor.primaryText)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(MRColor.secondaryText)
                        .frame(width: 38, height: 38)
                        .background(MRColor.secondarySurface)
                        .clipShape(Circle())
                }
                .buttonStyle(MRPressableStyle())
            }

            if let date = visit.date {
                Label(date.mrDayTitle, systemImage: "calendar")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(MRColor.secondaryText)
            }
            if visit.photoCount > 0 {
                Label("사진 \(visit.photoCount)장", systemImage: "photo.stack")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(MRColor.secondaryText)
            }
        }
        .mrPaper(padding: 17)
    }
}

struct SettingsView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(StoreService.self) private var store
    @AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.poster.rawValue
    @State private var showingPaywall = false

    var body: some View {
        List {
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
                    Text("MapRibbon")
                    Spacer()
                    Text("0.1.0 MVP").foregroundStyle(MRColor.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MRScreenBackground())
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
                    VStack(alignment: .leading, spacing: 5) {
                        MREyebrow(text: "Full Edition")
                        Text("MapRibbon 전체 기능")
                            .font(MRType.display(24))
                            .tracking(-0.3)
                        Text("한 번 구매하고 계속 사용합니다")
                            .font(.subheadline)
                            .foregroundStyle(MRColor.secondaryText)
                    }
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
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: 15) {
                    PaywallRow(symbol: "photo.badge.checkmark", text: "고해상도 저장과 워터마크 제거")
                    PaywallRow(symbol: "square.stack.3d.up", text: "모든 보드 템플릿")
                    PaywallRow(symbol: "clock.arrow.circlepath", text: "과거 날짜와 보드 무제한")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        await store.purchaseLifetime()
                        if store.isUnlocked { dismiss() }
                    }
                } label: {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else if let price = store.lifetimeProduct?.displayPrice {
                        Text("전체 기능 잠금 해제 · \(price)")
                    } else {
                        Text("전체 기능 잠금 해제")
                    }
                }
                .buttonStyle(MRPrimaryButtonStyle())

                Button("구매 복원") { Task { await store.restore() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(minHeight: 44)
                    .padding(.bottom, 10)
            }
            .padding(20)
        }
        .background(MRScreenBackground())
    }
}

private struct PremiumBoardSample: View {
    @State private var draft = BoardScreenshotFixture.makeDraft()

    var body: some View {
        BoardCanvasView(model: draft.renderModel, watermark: false)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(6)
            .background(MRColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.card, style: .continuous))
            .overlay { MRPlateFrame() }
            .overlay(alignment: .top) { MRPinDot(diameter: 9).offset(y: -3) }
            .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
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
