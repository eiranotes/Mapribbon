import SwiftUI
import SwiftData

struct GenerationFlowView: View {
    let summary: PhotoDaySummary
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BoardDraft?
    @State private var step: GenerationStep = .readingPhotos
    @State private var progress = 0.04
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    BoardEditorView(draft: draft, onClose: { dismiss() })
                } else if let errorMessage {
                    ContentUnavailableView(
                        "보드를 만들지 못했습니다",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .overlay(alignment: .bottom) {
                        Button("닫기") { dismiss() }
                            .buttonStyle(MRPrimaryButtonStyle())
                            .padding(20)
                    }
                } else {
                    GenerationProgressView(step: step, progress: progress)
                }
            }
            .background(MRColor.background.ignoresSafeArea())
        }
        .interactiveDismissDisabled(draft == nil && errorMessage == nil)
        .task {
            let generator = BoardGenerationService()
            do {
                draft = try await generator.generate(from: summary) { newStep, newProgress in
                    step = newStep
                    progress = newProgress
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct GenerationProgressView: View {
    let step: GenerationStep
    let progress: Double

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            MRLoadingRing(progress: progress)
            VStack(spacing: 8) {
                Text("보드 생성 중")
                    .font(.system(size: 24, weight: .bold))
                Text(step.title)
                    .font(.system(size: 15))
                    .foregroundStyle(MRColor.secondaryText)
            }
            VStack(alignment: .leading, spacing: 13) {
                ForEach(GenerationStep.allCases) { item in
                    HStack(spacing: 10) {
                        Image(systemName: stateSymbol(for: item))
                            .foregroundStyle(stateColor(for: item))
                        Text(item.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(item == step ? MRColor.primaryText : MRColor.secondaryText)
                        Spacer()
                    }
                }
            }
            .padding(18)
            .background(MRColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(MRColor.border) }
            .padding(.horizontal, 30)
            Spacer()
            Text("사진 원본은 기기 밖으로 전송되지 않습니다.")
                .font(.system(size: 12))
                .foregroundStyle(MRColor.secondaryText)
                .padding(.bottom, 24)
        }
    }

    private func stateSymbol(for item: GenerationStep) -> String {
        let all = GenerationStep.allCases
        guard let current = all.firstIndex(of: step), let index = all.firstIndex(of: item) else { return "circle" }
        if index < current { return "checkmark.circle.fill" }
        if index == current { return "circle.inset.filled" }
        return "circle"
    }

    private func stateColor(for item: GenerationStep) -> Color {
        let all = GenerationStep.allCases
        guard let current = all.firstIndex(of: step), let index = all.firstIndex(of: item) else { return MRColor.border }
        return index <= current ? MRColor.accent : MRColor.border
    }
}

struct BoardEditorView: View {
    @Bindable var draft: BoardDraft
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store

    @State private var showingPlaces = false
    @State private var showingExport = false
    @State private var showingPaywall = false
    @State private var exportedImage: UIImage?
    @State private var showingActivity = false
    @State private var toastMessage: String?
    @AppStorage("freeExportConsumed") private var freeExportConsumed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 15, y: 7)
                    .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    templatePicker
                    Button {
                        showingPlaces = true
                    } label: {
                        Label("장소와 사진 수정", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(MRSecondaryButtonStyle())

                    Button("저장 및 공유") {
                        if !store.isUnlocked && freeExportConsumed {
                            showingPaywall = true
                        } else {
                            showingExport = true
                        }
                    }
                    .buttonStyle(MRPrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, 12)
        }
        .background(MRColor.background)
        .navigationTitle("미리보기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("닫기") { onClose() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    TextField("보드 제목", text: $draft.title)
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingPlaces) {
            PlaceManagerView(draft: draft)
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(draft: draft) { image, action in
                exportedImage = image
                if !store.isUnlocked { freeExportConsumed = true }
                persist(image)
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
            if let exportedImage {
                ActivityView(items: [exportedImage])
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("MapRibbon", isPresented: Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )) {
            Button("확인", role: .cancel) { toastMessage = nil }
        } message: {
            Text(toastMessage ?? "")
        }
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("템플릿")
                .font(.system(size: 16, weight: .bold))
            HStack(spacing: 10) {
                ForEach(BoardTemplate.allCases) { template in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { draft.template = template }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: template.symbolName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(template.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(draft.template == template ? MRColor.accent : MRColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(draft.template == template ? MRColor.accentSoft : MRColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(draft.template == template ? MRColor.accent : MRColor.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func persist(_ image: UIImage) {
        guard let previewData = image.jpegData(compressionQuality: 0.86),
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
            let board = SavedBoard(
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
            modelContext.insert(board)
        }
        try? modelContext.save()
    }
}

enum ExportAction { case share, save }

struct ExportSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(StoreService.self) private var store
    let onExport: (UIImage, ExportAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .story
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Picker("출력 비율", selection: $format) {
                    ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                    .aspectRatio(format.aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                    .frame(maxHeight: 480)

                HStack(spacing: 12) {
                    Button {
                        Task { if let image = await render() { onExport(image, .save) } }
                    } label: { Label("저장", systemImage: "square.and.arrow.down") }
                    .buttonStyle(MRSecondaryButtonStyle())

                    Button {
                        Task { if let image = await render() { onExport(image, .share) } }
                    } label: { Label("공유", systemImage: "square.and.arrow.up") }
                    .buttonStyle(MRPrimaryButtonStyle())
                }
            }
            .padding(20)
            .background(MRColor.background)
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
            .overlay { if isRendering { ProgressView().padding(24).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14)) } }
        }
    }

    @MainActor
    private func render() async -> UIImage? {
        isRendering = true
        defer { isRendering = false }
        let content = BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
            .frame(width: format.size.width, height: format.size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage
    }
}

struct PlaceManagerView: View {
    @Bindable var draft: BoardDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach($draft.places) { $place in
                    NavigationLink {
                        PlaceEditorView(place: $place, draft: draft)
                    } label: {
                        HStack(spacing: 12) {
                            AssetThumbnailView(identifier: place.representativeAssetIdentifier, size: CGSize(width: 56, height: 56))
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .opacity(place.isHidden ? 0.35 : 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.title).font(.system(size: 15, weight: .semibold))
                                Text("사진 \(place.photoCount)장 · \(place.startDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 12)).foregroundStyle(MRColor.secondaryText)
                            }
                        }
                    }
                }
                .onMove { source, destination in
                    draft.places.move(fromOffsets: source, toOffset: destination)
                }
            }
            .navigationTitle("장소와 사진")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } }
            }
        }
    }
}

struct PlaceEditorView: View {
    @Binding var place: BoardPlace
    @Bindable var draft: BoardDraft

    var body: some View {
        Form {
            Section("장소") {
                TextField("장소 이름", text: $place.title)
                TextField("설명", text: Binding($place.subtitle, replacingNilWith: ""))
                Toggle("보드에 표시", isOn: Binding(get: { !place.isHidden }, set: { place.isHidden = !$0 }))
            }

            Section("대표 사진") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(place.assetIdentifiers, id: \.self) { identifier in
                        Button {
                            Task {
                                if let image = await PhotoImageService.shared.image(for: identifier, targetSize: CGSize(width: 700, height: 700), highQuality: true) {
                                    place.representativeAssetIdentifier = identifier
                                    draft.photoImages[identifier] = image
                                }
                            }
                        } label: {
                            AssetThumbnailView(identifier: identifier, size: CGSize(width: 180, height: 180))
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .bottomTrailing) {
                                    if place.representativeAssetIdentifier == identifier {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 23))
                                            .foregroundStyle(MRColor.accent)
                                            .background(Circle().fill(.white))
                                            .padding(6)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(place.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}


private struct BoardRouteSegment: Identifiable {
    let id: Int
    let start: CGPoint
    let end: CGPoint
}

private struct TexturedRopeSegment: View {
    let start: CGPoint
    let end: CGPoint
    let thickness: CGFloat

    var body: some View {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let length = max(sqrt(deltaX * deltaX + deltaY * deltaY), thickness)
        let angle = Angle(radians: Double(atan2(deltaY, deltaX)))

        Image("RouteRopeRed")
            .resizable(
                capInsets: EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10),
                resizingMode: .tile
            )
            .interpolation(.high)
            .frame(width: length + thickness * 0.7, height: thickness)
            .rotationEffect(angle)
            .position(
                x: (start.x + end.x) * 0.5,
                y: (start.y + end.y) * 0.5
            )
            .shadow(color: .black.opacity(0.22), radius: thickness * 0.28, y: thickness * 0.18)
    }
}

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

struct BoardCanvasView: View {
    let model: BoardRenderModel
    let watermark: Bool

    var body: some View {
        GeometryReader { proxy in
            switch model.template {
            case .ribbon: ribbon(in: proxy.size)
            case .editorial: editorial(in: proxy.size)
            case .postcard: postcard(in: proxy.size)
            case .scrapbook: scrapbook(in: proxy.size)
            }
        }
        .background(MRColor.paper)
        .clipped()
    }

    private func ribbon(in size: CGSize) -> some View {
        ZStack {
            Image(uiImage: model.mapImage).resizable().scaledToFill()
            Color.white.opacity(0.10)
            ropeLayer(size)
            photoLayer(size, scale: 0.19)
            pinLayer(size)
            header(size, dark: true)
            footer(size, dark: true)
        }
    }

    private func editorial(in size: CGSize) -> some View {
        ZStack(alignment: .top) {
            MRColor.paper
            VStack(spacing: 0) {
                ZStack {
                    Image(uiImage: model.mapImage).resizable().scaledToFill()
                    ropeLayer(CGSize(width: size.width, height: size.height * 0.68))
                    pinLayer(CGSize(width: size.width, height: size.height * 0.68))
                }
                .frame(height: size.height * 0.68)
                HStack(spacing: size.width * 0.018) {
                    ForEach(Array(model.visiblePlaces.prefix(4))) { place in
                        if let image = model.photoImages[place.representativeAssetIdentifier] {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).clipped()
                        }
                    }
                }
                .frame(height: size.height * 0.22)
                .padding(size.width * 0.04)
            }
            header(size, dark: false)
            footer(size, dark: false)
        }
    }

    private func postcard(in size: CGSize) -> some View {
        ZStack {
            MRColor.paper
            Image(uiImage: model.mapImage).resizable().scaledToFill()
                .padding(size.width * 0.07)
                .overlay { RoundedRectangle(cornerRadius: size.width * 0.01).stroke(Color.black.opacity(0.10), lineWidth: 1).padding(size.width * 0.07) }
            ropeLayer(size)
            photoLayer(size, scale: 0.17)
            pinLayer(size)
            header(size, dark: false)
            footer(size, dark: false)
        }
    }

    private func scrapbook(in size: CGSize) -> some View {
        ZStack {
            Color(hex: 0xEDE4D5)
            Image(uiImage: model.mapImage).resizable().scaledToFill().opacity(0.78)
            ropeLayer(size)
            photoLayer(size, scale: 0.20)
            pinLayer(size)
            ForEach(0..<3, id: \.self) { index in
                Rectangle().fill(Color(hex: 0xD9C29D).opacity(0.75))
                    .frame(width: size.width * 0.18, height: size.height * 0.026)
                    .rotationEffect(.degrees(index == 1 ? -12 : 9))
                    .position(x: size.width * [0.20, 0.78, 0.55][index], y: size.height * [0.18, 0.42, 0.82][index])
            }
            header(size, dark: false)
            footer(size, dark: false)
        }
    }

    @ViewBuilder private func ropeLayer(_ size: CGSize) -> some View {
        let points = routePoints(in: size)
        let thickness = max(5, size.width * 0.018)

        ZStack {
            ForEach(routeSegments(from: points)) { segment in
                TexturedRopeSegment(
                    start: segment.start,
                    end: segment.end,
                    thickness: thickness
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder private func pinLayer(_ size: CGSize) -> some View {
        let points = routePoints(in: size)
        let pinWidth = max(28, size.width * 0.082)
        let pinHeight = pinWidth * 1.60
        let pinAssets = [
            "RoutePinBlue",
            "RoutePinTeal",
            "RoutePinYellow",
            "RoutePinCream",
            "RoutePinRed",
            "RoutePinGreen"
        ]

        ZStack {
            ForEach(points.indices, id: \.self) { index in
                Image(pinAssets[index % pinAssets.count])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: pinWidth, height: pinHeight)
                    .shadow(color: .black.opacity(0.25), radius: pinWidth * 0.10, y: pinWidth * 0.08)
                    .position(
                        x: points[index].x,
                        y: points[index].y + pinHeight * 0.29
                    )
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func routePoints(in size: CGSize) -> [CGPoint] {
        switch model.template {
        case .ribbon:
            return cardAnchorPoints(count: model.visiblePlaces.count, size: size, scale: 0.19)
        case .scrapbook:
            return cardAnchorPoints(count: model.visiblePlaces.count, size: size, scale: 0.20)
        case .editorial, .postcard:
            return model.visiblePlaces.compactMap { place in
                guard let point = model.normalizedPoints[place.id] else { return nil }
                return CGPoint(x: point.x * size.width, y: point.y * size.height)
            }
        }
    }

    private func cardAnchorPoints(count: Int, size: CGSize, scale: CGFloat) -> [CGPoint] {
        let positions = cardPositions(count: count)
        let cardHeight = size.height * scale * 0.86

        return positions.map { position in
            CGPoint(
                x: position.x * size.width,
                y: position.y * size.height - cardHeight * 0.40
            )
        }
    }

    private func routeSegments(from points: [CGPoint]) -> [BoardRouteSegment] {
        guard points.count > 1 else { return [] }

        return (0..<(points.count - 1)).map { index in
            BoardRouteSegment(id: index, start: points[index], end: points[index + 1])
        }
    }

    @ViewBuilder private func photoLayer(_ size: CGSize, scale: CGFloat) -> some View {
        let positions = cardPositions(count: model.visiblePlaces.count)
        ForEach(Array(model.visiblePlaces.enumerated()), id: \.element.id) { index, place in
            if index < positions.count, let image = model.photoImages[place.representativeAssetIdentifier] {
                VStack(spacing: 0) {
                    Image(uiImage: image).resizable().scaledToFill().clipped()
                    Rectangle().fill(.white).frame(height: size.height * 0.018)
                }
                .padding(size.width * 0.012)
                .background(.white)
                .frame(width: size.width * scale, height: size.height * scale * 0.86)
                .shadow(color: .black.opacity(0.18), radius: size.width * 0.015, y: size.width * 0.01)
                .rotationEffect(.degrees([ -5, 4, -2, 6, -4, 3, -3, 5 ][index % 8]))
                .position(x: positions[index].x * size.width, y: positions[index].y * size.height)
            }
        }
    }

    private func header(_ size: CGSize, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: size.height * 0.004) {
            Text(model.date.mrBoardDate.uppercased())
                .font(.system(size: size.width * 0.032, weight: .semibold))
            Text(model.title)
                .font(.system(size: size.width * 0.070, weight: .bold, design: model.template == .postcard ? .serif : .default))
                .lineLimit(2)
        }
        .foregroundStyle(dark ? Color.black.opacity(0.82) : MRColor.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.width * 0.065)
        .padding(.top, size.height * 0.05)
    }

    private func footer(_ size: CGSize, dark: Bool) -> some View {
        VStack {
            Spacer()
            HStack {
                Text("사진 \(model.photoCount)장 · 장소 \(model.visiblePlaces.count)곳")
                Spacer()
                if watermark { Text("Made with MapRibbon") }
            }
            .font(.system(size: size.width * 0.028, weight: .semibold))
            .foregroundStyle(dark ? Color.black.opacity(0.58) : MRColor.ink.opacity(0.64))
            .padding(.horizontal, size.width * 0.065)
            .padding(.bottom, size.height * 0.035)
        }
    }

    private func cardPositions(count: Int) -> [CGPoint] {
        let all = [
            CGPoint(x: 0.22, y: 0.29), CGPoint(x: 0.76, y: 0.26),
            CGPoint(x: 0.69, y: 0.52), CGPoint(x: 0.28, y: 0.62),
            CGPoint(x: 0.72, y: 0.76), CGPoint(x: 0.22, y: 0.82),
            CGPoint(x: 0.49, y: 0.40), CGPoint(x: 0.50, y: 0.70)
        ]
        return Array(all.prefix(max(0, min(count, all.count))))
    }
}

struct SavedBoardDetailView: View {
    let board: SavedBoard
    @State private var showingActivity = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let image = UIImage(data: board.previewImageData) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.10), radius: 15, y: 7)
                    Button { showingActivity = true } label: { Label("공유", systemImage: "square.and.arrow.up") }
                        .buttonStyle(MRPrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(MRColor.background)
        .navigationTitle(board.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingActivity) {
            if let image = UIImage(data: board.previewImageData) { ActivityView(items: [image]) }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
