from pathlib import Path

ROOT = Path('.')


def replace_between(text: str, start: str, end: str, replacement: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'missing start marker: {start}')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'missing end marker: {end}')
    return text[:a] + replacement.rstrip() + '\n\n' + text[b:]


def replace_exact(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)

board_path = ROOT / 'MapRibbon/Views/BoardViews.swift'
board = board_path.read_text(encoding='utf-8')

editor = r'''struct BoardEditorView: View {
    @Bindable var draft: BoardDraft
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store

    @State private var showingPlaces = false
    @State private var showingExport = false
    @State private var showingPaywall = false
    @State private var showingTitleEditor = false
    @State private var showingTemplatePicker = false
    @State private var showingAddMenu = false
    @State private var showingCloseConfirmation = false
    @State private var exportedImage: UIImage?
    @State private var showingActivity = false
    @State private var toastMessage: String?
    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @AppStorage("freeExportConsumed") private var freeExportConsumed = false

    var body: some View {
        VStack(spacing: 0) {
            BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.13), radius: 15, y: 8)

            Spacer(minLength: 0)
        }
        .background(MRColor.background.ignoresSafeArea())
        .navigationTitle("보드 편집")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(MRColor.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: requestClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MRColor.primaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("뒤로")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingTitleEditor = true
                    } label: {
                        Label("제목 편집", systemImage: "pencil")
                    }

                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("템플릿 변경", systemImage: "square.stack.3d.up")
                    }

                    Divider()

                    Button {
                        presentExport()
                    } label: {
                        Label("저장 및 공유", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(MRColor.primaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("보드 메뉴")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            editorToolBar
        }
        .sheet(isPresented: $showingPlaces, onDismiss: { hasUnsavedChanges = true }) {
            PlaceManagerView(draft: draft)
        }
        .sheet(isPresented: $showingTitleEditor) {
            TitleEditorSheet(title: $draft.title)
                .presentationDetents([.height(230)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerSheet(draft: draft)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(draft: draft) { image, action in
                exportedImage = image
                if !store.isUnlocked { freeExportConsumed = true }
                persist(image)
                hasUnsavedChanges = false
                switch action {
                case .share:
                    showingExport = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showingActivity = true }
                case .save:
                    Task {
                        do {
                            try await PhotoSaveService.save(image)
                            toastMessage = "사진 보관함에 저장했습니다."
                        } catch {
                            toastMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingActivity) {
            if let exportedImage { ActivityView(items: [exportedImage]) }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .alert("MapRibbon", isPresented: Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )) {
            Button("확인", role: .cancel) { toastMessage = nil }
        } message: { Text(toastMessage ?? "") }
        .confirmationDialog("보드에 추가", isPresented: $showingAddMenu, titleVisibility: .visible) {
            Button("사진 선택") { showingPlaces = true }
            Button("장소 편집") { showingPlaces = true }
            Button("제목 메모 편집") { showingTitleEditor = true }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("변경사항을 저장할까요?", isPresented: $showingCloseConfirmation, titleVisibility: .visible) {
            Button("저장하고 닫기") {
                Task {
                    await saveDraftPreview()
                    onClose()
                }
            }
            Button("저장하지 않고 닫기", role: .destructive) { onClose() }
            Button("취소", role: .cancel) {}
        }
        .onChange(of: draft.title) { _, _ in hasUnsavedChanges = true }
        .onChange(of: draft.template) { _, _ in hasUnsavedChanges = true }
        .onChange(of: draft.places) { _, _ in hasUnsavedChanges = true }
    }

    private var editorToolBar: some View {
        HStack(alignment: .top, spacing: 0) {
            BoardEditorToolButton(title: "사진 추가", symbol: "photo.badge.plus") {
                showingPlaces = true
            }

            BoardEditorToolButton(title: "장소 추가", symbol: "mappin.and.ellipse") {
                showingPlaces = true
            }

            Button {
                showingAddMenu = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(MRColor.accent)
                    .clipShape(Circle())
                    .shadow(color: MRColor.accent.opacity(0.22), radius: 8, y: 4)
            }
            .buttonStyle(MRPressableStyle())
            .frame(maxWidth: .infinity)
            .accessibilityLabel("보드에 추가")

            BoardEditorToolButton(title: "순서 변경", symbol: "arrow.up.arrow.down") {
                showingPlaces = true
            }

            BoardEditorToolButton(title: "저장 및 공유", symbol: "square.and.arrow.up") {
                presentExport()
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 14)
        .padding(.bottom, 7)
        .background(MRColor.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.10), radius: 18, y: -4)
    }

    private func requestClose() {
        if hasUnsavedChanges { showingCloseConfirmation = true } else { onClose() }
    }

    private func presentExport() {
        if !store.isUnlocked && freeExportConsumed {
            showingPaywall = true
        } else {
            showingExport = true
        }
    }

    @MainActor
    private func saveDraftPreview() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let size = CGSize(width: 750, height: 1_000)
        let content = BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(size)
        if let image = renderer.uiImage {
            persist(image)
            hasUnsavedChanges = false
        }
    }

    private func persist(_ image: UIImage) {
        guard let previewData = image.jpegData(compressionQuality: 0.88),
              let payloadData = try? JSONEncoder().encode(
                BoardArchivePayload(date: draft.date, title: draft.title, places: draft.places, template: draft.template)
              ) else { return }

        let regions = Array(Set(draft.places.compactMap { RegionNormalizer.key(from: $0.administrativeArea) })).sorted()
        let regionJSON = String(data: (try? JSONEncoder().encode(regions)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        let identifier = draft.id
        let descriptor = FetchDescriptor<SavedBoard>(predicate: #Predicate { $0.id == identifier })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.date = draft.date
            existing.createdAt = .now
            existing.title = draft.title
            existing.photoCount = draft.places.reduce(0) { $0 + $1.photoCount }
            existing.placeCount = draft.places.filter { !$0.isHidden }.count
            existing.templateRawValue = draft.template.rawValue
            existing.previewImageData = previewData
            existing.payloadData = payloadData
            existing.regionKeysJSON = regionJSON
        } else {
            modelContext.insert(
                SavedBoard(
                    id: draft.id,
                    date: draft.date,
                    title: draft.title,
                    photoCount: draft.places.reduce(0) { $0 + $1.photoCount },
                    placeCount: draft.places.filter { !$0.isHidden }.count,
                    templateRawValue: draft.template.rawValue,
                    previewImageData: previewData,
                    payloadData: payloadData,
                    regionKeysJSON: regionJSON
                )
            )
        }
        try? modelContext.save()
    }
}

private struct BoardEditorToolButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 28)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(MRColor.secondaryText)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(MRPressableStyle())
        .accessibilityLabel(title)
    }
}

private struct TemplatePickerSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BoardTemplate.allCases) { template in
                        Button {
                            draft.template = template
                            dismiss()
                        } label: {
                            TemplateChoiceCard(template: template, isSelected: draft.template == template)
                                .frame(width: 132)
                        }
                        .buttonStyle(MRPressableStyle())
                    }
                }
                .padding(20)
            }
            .background(MRColor.background)
            .navigationTitle("템플릿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } }
            }
        }
    }
}'''
board = replace_between(board, 'struct BoardEditorView: View {', 'private struct TitleEditorSheet', editor)

route_types_old = '''private struct BoardRouteSegment: Identifiable {
    let id: Int
    let start: CGPoint
    let end: CGPoint
}'''
route_types_new = '''enum BoardRouteLayout {
    static func edgePairs(for count: Int) -> [(Int, Int)] {
        switch count {
        case 0...1:
            return []
        case 2:
            return [(0, 1)]
        case 3:
            return [(0, 1), (0, 2)]
        case 4:
            return [(0, 1), (0, 2), (2, 3)]
        default:
            var edges = [(0, 1), (0, 2), (2, 3), (1, 4), (3, 4)]
            if count > 5 {
                edges.append(contentsOf: (5..<count).map { ($0 - 1, $0) })
            }
            return edges
        }
    }
}

private struct BoardRouteSegment: Identifiable {
    let id: Int
    let start: CGPoint
    let end: CGPoint
}'''
board = replace_exact(board, route_types_old, route_types_new, 'route layout type')

ribbon = r'''    private func ribbon(in size: CGSize) -> some View {
        let boardRect = CGRect(origin: .zero, size: size)
        let mapRect = boardRect.insetBy(dx: size.width * 0.031, dy: size.width * 0.031)

        return ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.026, style: .continuous)
                .fill(Color(hex: 0xA66F3F))
                .overlay {
                    CorkBoardTexture()
                        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.026, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: size.width * 0.026, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: max(1, size.width * 0.002))
                }
                .shadow(color: .black.opacity(0.20), radius: size.width * 0.020, y: size.width * 0.012)

            mapPaper(in: mapRect)
            ropeLayer(in: mapRect, scale: 0.215)
            photoLayer(in: mapRect, scale: 0.215, labeled: true)
            pinLayer(in: mapRect, scale: 0.215)
            titleNote(in: mapRect)
            footer(in: mapRect, dark: true)
        }
    }'''
board = replace_between(board, '    private func ribbon(in size: CGSize) -> some View {', '    private func editorial(in size: CGSize) -> some View {', ribbon)

board = board.replace('ropeLayer(in: mapRect, scale: 0.245)', 'ropeLayer(in: mapRect, scale: 0.215)')
board = board.replace('photoLayer(in: mapRect, scale: 0.245, labeled: true)', 'photoLayer(in: mapRect, scale: 0.215, labeled: true)')
board = board.replace('pinLayer(in: mapRect, scale: 0.245)', 'pinLayer(in: mapRect, scale: 0.215)')

map_old = '''            Color(hex: 0xF4EFE5).opacity(0.30)
            PaperGrain()'''
map_new = '''            Color(hex: 0xF4EFE5).opacity(0.18)
            PaperGrain().opacity(0.72)'''
board = replace_exact(board, map_old, map_new, 'map paper tone')

rope = r'''    private func ropeLayer(in rect: CGRect, scale: CGFloat) -> some View {
        Canvas { context, _ in
            let points = routePoints(in: rect, scale: scale)
            let thickness = max(4.5, rect.width * 0.0105)
            let rope = context.resolve(Image("RouteRopeRed"))
            let tileWidth = thickness * 1.42

            for segment in routeSegments(from: points) {
                let dx = segment.end.x - segment.start.x
                let dy = segment.end.y - segment.start.y
                let length = max(sqrt(dx * dx + dy * dy), thickness)
                let angle = Angle(radians: Double(atan2(dy, dx)))
                let midpoint = CGPoint(x: (segment.start.x + segment.end.x) * 0.5, y: (segment.start.y + segment.end.y) * 0.5)

                context.drawLayer { layer in
                    layer.translateBy(x: midpoint.x, y: midpoint.y)
                    layer.rotate(by: angle)
                    layer.addFilter(.shadow(color: .black.opacity(0.28), radius: thickness * 0.42, x: 0, y: thickness * 0.30))

                    let capsuleRect = CGRect(
                        x: -length * 0.5 - thickness * 0.30,
                        y: -thickness * 0.5,
                        width: length + thickness * 0.60,
                        height: thickness
                    )
                    layer.clip(to: Capsule().path(in: capsuleRect))

                    var x = capsuleRect.minX - 1
                    while x < capsuleRect.maxX {
                        layer.draw(rope, in: CGRect(x: x, y: capsuleRect.minY, width: tileWidth + 0.8, height: thickness))
                        x += tileWidth - 0.4
                    }
                }

                var highlight = Path()
                highlight.move(to: segment.start)
                highlight.addLine(to: segment.end)
                context.stroke(
                    highlight,
                    with: .color(.white.opacity(0.10)),
                    style: StrokeStyle(lineWidth: max(0.7, thickness * 0.09), lineCap: .round)
                )
            }
        }
    }'''
board = replace_between(board, '    private func ropeLayer(in rect: CGRect, scale: CGFloat) -> some View {', '    private func pinLayer(in rect: CGRect, scale: CGFloat) -> some View {', rope)

pin = r'''    private func pinLayer(in rect: CGRect, scale: CGFloat) -> some View {
        let points = routePoints(in: rect, scale: scale)
        let pinWidth = max(22, rect.width * 0.054)
        let pinHeight = pinWidth * 1.60
        let assets = ["RoutePinBlue", "RoutePinTeal", "RoutePinYellow", "RoutePinCream", "RoutePinRed", "RoutePinGreen"]

        return ZStack {
            ForEach(points.indices, id: \.self) { index in
                Image(assets[index % assets.count])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: pinWidth, height: pinHeight)
                    .shadow(color: .black.opacity(0.24), radius: pinWidth * 0.08, y: pinWidth * 0.06)
                    .position(x: points[index].x, y: points[index].y - pinHeight * 0.31)
            }
        }
    }'''
board = replace_between(board, '    private func pinLayer(in rect: CGRect, scale: CGFloat) -> some View {', '    private func photoLayer(in rect: CGRect, scale: CGFloat, labeled: Bool) -> some View {', pin)

photo = r'''    private func photoLayer(in rect: CGRect, scale: CGFloat, labeled: Bool) -> some View {
        let positions = cardPositions(count: model.visiblePlaces.count)
        return ZStack {
            ForEach(Array(model.visiblePlaces.enumerated()), id: \.element.id) { index, place in
                if index < positions.count, let image = model.photoImages[place.representativeAssetIdentifier] {
                    BoardPhotoCard(
                        place: place,
                        image: image,
                        size: rect.size,
                        scale: scale,
                        labeled: labeled,
                        variant: index
                    )
                    .rotationEffect(.degrees(cardRotationDegrees(for: index)))
                    .position(x: rect.minX + positions[index].x * rect.width, y: rect.minY + positions[index].y * rect.height)
                }
            }
        }
    }'''
board = replace_between(board, '    private func photoLayer(in rect: CGRect, scale: CGFloat, labeled: Bool) -> some View {', '    private func titleNote(in rect: CGRect) -> some View {', photo)

board = board.replace('let width = rect.width * 0.42', 'let width = rect.width * 0.40', 1)
board = board.replace('.position(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.10)', '.position(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.095)', 1)
board = board.replace('.position(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.045)', '.position(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.043)', 1)

old_rotation = '''    private func cardRotationDegrees(for index: Int) -> Double {
        let values: [Double] = [-4, 3, -2, 4, -3, 2, -2, 3]
        return values[index % values.count]
    }'''
new_rotation = '''    private func cardRotationDegrees(for index: Int) -> Double {
        let values: [Double] = [-2, 3, -2, 2, 4, -2, 2, -3]
        return values[index % values.count]
    }'''
board = replace_exact(board, old_rotation, new_rotation, 'card rotation')

route_segments = r'''    private func routeSegments(from points: [CGPoint]) -> [BoardRouteSegment] {
        BoardRouteLayout.edgePairs(for: points.count).enumerated().compactMap { index, pair in
            guard points.indices.contains(pair.0), points.indices.contains(pair.1) else { return nil }
            return BoardRouteSegment(id: index, start: points[pair.0], end: points[pair.1])
        }
    }'''
board = replace_between(board, '    private func routeSegments(from points: [CGPoint]) -> [BoardRouteSegment] {', '    private func cardPositions(count: Int) -> [CGPoint] {', route_segments)

old_positions = '''    private func cardPositions(count: Int) -> [CGPoint] {
        let all = [
            CGPoint(x: 0.25, y: 0.31), CGPoint(x: 0.74, y: 0.40),
            CGPoint(x: 0.24, y: 0.56), CGPoint(x: 0.30, y: 0.77),
            CGPoint(x: 0.73, y: 0.73), CGPoint(x: 0.22, y: 0.88),
            CGPoint(x: 0.52, y: 0.49), CGPoint(x: 0.52, y: 0.82)
        ]
        return Array(all.prefix(max(0, min(count, all.count))))
    }'''
new_positions = '''    private func cardPositions(count: Int) -> [CGPoint] {
        let all = [
            CGPoint(x: 0.245, y: 0.285), CGPoint(x: 0.760, y: 0.400),
            CGPoint(x: 0.240, y: 0.565), CGPoint(x: 0.300, y: 0.820),
            CGPoint(x: 0.740, y: 0.745), CGPoint(x: 0.215, y: 0.900),
            CGPoint(x: 0.520, y: 0.500), CGPoint(x: 0.525, y: 0.845)
        ]
        return Array(all.prefix(max(0, min(count, all.count))))
    }'''
board = replace_exact(board, old_positions, new_positions, 'card positions')

card = r'''private struct BoardPhotoCard: View {
    let place: BoardPlace
    let image: UIImage
    let size: CGSize
    let scale: CGFloat
    let labeled: Bool
    let variant: Int

    var body: some View {
        let width = size.width * scale
        let height = width * (labeled ? 1.23 : 1.04)
        let xDirections: [CGFloat] = [1, -1, 1, -1, 1]
        let direction = xDirections[variant % xDirections.count]
        let rearAngles: [Double] = [2.0, -2.4, 1.5, -1.8, 2.6]
        let rearAngle = rearAngles[variant % rearAngles.count]

        ZStack {
            Rectangle()
                .fill(Color(hex: 0xF8F6F0))
                .frame(width: width, height: height)
                .rotationEffect(.degrees(rearAngle))
                .offset(x: direction * width * 0.070, y: height * 0.045)

            Rectangle()
                .fill(Color.white.opacity(0.96))
                .frame(width: width, height: height)
                .rotationEffect(.degrees(-rearAngle * 0.45))
                .offset(x: -direction * width * 0.035, y: height * 0.025)

            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.87, height: labeled ? height * 0.67 : height * 0.80)
                    .clipped()

                if labeled {
                    VStack(alignment: .leading, spacing: max(1, width * 0.010)) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(place.title)
                                .font(.system(size: width * 0.072, weight: .bold))
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(place.photoCount)장")
                                .font(.system(size: width * 0.057, weight: .bold))
                                .foregroundStyle(MRColor.accent)
                        }

                        Text(place.subtitle ?? place.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: width * 0.049, weight: .medium))
                            .foregroundStyle(MRColor.ink.opacity(0.66))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, width * 0.055)
                    .padding(.top, width * 0.040)
                    .padding(.bottom, width * 0.025)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(hex: 0xFBFAF6))
                } else {
                    Rectangle().fill(.white).frame(maxHeight: .infinity)
                }
            }
            .padding(width * 0.052)
            .background(Color(hex: 0xFCFBF7))
            .frame(width: width, height: height)
            .overlay {
                Rectangle().stroke(Color.black.opacity(0.045), lineWidth: max(0.5, width * 0.003))
            }
        }
        .shadow(color: .black.opacity(0.22), radius: size.width * 0.013, y: size.width * 0.010)
    }
}'''
board = replace_between(board, 'private struct BoardPhotoCard: View {', 'private struct CorkBoardTexture: View {', card)

cork = r'''private struct CorkBoardTexture: View {
    var body: some View {
        Canvas { context, size in
            let bounds = Path(CGRect(origin: .zero, size: size))
            context.fill(
                bounds,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xB9824E), Color(hex: 0x8E5B32)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            var state: UInt64 = 0x9E3779B97F4A7C15
            func random() -> CGFloat {
                state = state &* 2862933555777941757 &+ 3037000493
                return CGFloat((state >> 33) & 0xFFFF) / CGFloat(0xFFFF)
            }

            let fleckColors = [
                Color(hex: 0x4F2F1C).opacity(0.28),
                Color(hex: 0x6D4226).opacity(0.32),
                Color(hex: 0xD7AC72).opacity(0.34),
                Color(hex: 0xE9C997).opacity(0.24),
                Color.black.opacity(0.13)
            ]

            for index in 0..<980 {
                let x = random() * size.width
                let y = random() * size.height
                let width = max(0.8, random() * size.width * 0.010)
                let height = max(0.5, width * (0.18 + random() * 0.48))
                let angle = (random() - 0.5) * 1.1
                var fleck = Path(roundedRect: CGRect(x: -width * 0.5, y: -height * 0.5, width: width, height: height), cornerRadius: height * 0.45)
                let transform = CGAffineTransform(translationX: x, y: y).rotated(by: angle)
                fleck = fleck.applying(transform)
                context.fill(fleck, with: .color(fleckColors[index % fleckColors.count]))
            }

            for index in 0..<95 {
                let y = random() * size.height
                var fiber = Path()
                fiber.move(to: CGPoint(x: random() * size.width * 0.25, y: y))
                fiber.addCurve(
                    to: CGPoint(x: size.width * (0.70 + random() * 0.30), y: y + (random() - 0.5) * 12),
                    control1: CGPoint(x: size.width * 0.34, y: y - 5 + random() * 10),
                    control2: CGPoint(x: size.width * 0.66, y: y - 5 + random() * 10)
                )
                context.stroke(fiber, with: .color(Color(hex: 0xE1B27A).opacity(index % 3 == 0 ? 0.18 : 0.09)), lineWidth: 0.45 + random() * 0.6)
            }
        }
        .allowsHitTesting(false)
    }
}'''
board = replace_between(board, 'private struct CorkBoardTexture: View {', 'private struct PaperGrain: View {', cork)

board_path.write_text(board, encoding='utf-8')

app_path = ROOT / 'MapRibbon/App/MapRibbonApp.swift'
app = app_path.read_text(encoding='utf-8')
app = replace_exact(
    app,
    '.aspectRatio(9.0 / 16.0, contentMode: .fit)',
    '.aspectRatio(3.0 / 4.0, contentMode: .fit)',
    'board canvas screenshot ratio'
)
app_path.write_text(app, encoding='utf-8')

settings_path = ROOT / 'MapRibbon/Views/AtlasSettingsViews.swift'
settings = settings_path.read_text(encoding='utf-8')
settings = settings.replace('@AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.story.rawValue', '@AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.poster.rawValue')
settings_path.write_text(settings, encoding='utf-8')

board = board_path.read_text(encoding='utf-8')
board = board.replace('@AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.story.rawValue', '@AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.poster.rawValue')
board = board.replace('@State private var format: ExportFormat = .story', '@State private var format: ExportFormat = .poster')
board = board.replace('format = ExportFormat(rawValue: defaultFormat) ?? .story', 'format = ExportFormat(rawValue: defaultFormat) ?? .poster')
board_path.write_text(board, encoding='utf-8')

tests_path = ROOT / 'MapRibbonTests/PhotoClustererTests.swift'
tests = tests_path.read_text(encoding='utf-8')
insert = '''
    func testReferenceRibbonUsesBranchedRouteGraph() {
        let edges = BoardRouteLayout.edgePairs(for: 5).map { [$0.0, $0.1] }
        XCTAssertEqual(edges, [[0, 1], [0, 2], [2, 3], [1, 4], [3, 4]])
    }

    func testReferenceRibbonExtendsSequentiallyAfterFivePlaces() {
        let edges = BoardRouteLayout.edgePairs(for: 7).map { [$0.0, $0.1] }
        XCTAssertEqual(edges.suffix(2), [[4, 5], [5, 6]])
    }
'''
needle = '    private func make(id: String, date: Date, latitude: Double, longitude: Double) -> PhotoAssetSnapshot {'
if insert.strip() not in tests:
    tests = tests.replace(needle, insert + '\n' + needle, 1)
tests_path.write_text(tests, encoding='utf-8')

ci_path = ROOT / '.github/workflows/ios-ci.yml'
ci = ci_path.read_text(encoding='utf-8')
ci = ci.replace('--batteryState charged --batteryLevel 100', '--batteryState discharging --batteryLevel 100')
ci = ci.replace('xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" "$flag"', 'xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" "$flag" -AppleLanguages "(ko)" -AppleLocale "ko_KR"')
ci_path.write_text(ci, encoding='utf-8')
