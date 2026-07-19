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
            .toolbar {
                if draft == nil && errorMessage == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { dismiss() }
                    }
                }
            }
        }
        .task {
            let generator = BoardGenerationService()
            do {
                draft = try await generator.generate(from: summary) { newStep, newProgress in
                    step = newStep
                    progress = newProgress
                }
            } catch is CancellationError {
                return
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
        VStack(spacing: 26) {
            Spacer()
            MRLoadingRing(progress: progress)
            VStack(spacing: 7) {
                Text("보드 생성 중")
                    .font(.title2.weight(.bold))
                Text(step.title)
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
            }
            VStack(alignment: .leading, spacing: 13) {
                ForEach(GenerationStep.allCases) { item in
                    HStack(spacing: 10) {
                        Image(systemName: stateSymbol(for: item))
                            .foregroundStyle(stateColor(for: item))
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(item == step ? MRColor.primaryText : MRColor.secondaryText)
                        Spacer()
                    }
                }
            }
            .mrCard(padding: 18, shadow: false)
            .padding(.horizontal, 28)
            Spacer()
            Text("사진 원본은 기기 밖으로 전송되지 않습니다.")
                .font(.footnote)
                .foregroundStyle(MRColor.secondaryText)
                .padding(.bottom, 20)
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
    @State private var showingTitleEditor = false
    @State private var showingCloseConfirmation = false
    @State private var exportedImage: UIImage?
    @State private var showingActivity = false
    @State private var toastMessage: String?
    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @AppStorage("freeExportConsumed") private var freeExportConsumed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                    .padding(.horizontal, 16)

                templatePicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
            }
            .padding(.top, 10)
        }
        .background(MRColor.background)
        .navigationTitle("보드 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("닫기") {
                    if hasUnsavedChanges { showingCloseConfirmation = true } else { onClose() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingTitleEditor = true } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("보드 제목 편집")
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .sheet(isPresented: $showingPlaces, onDismiss: { hasUnsavedChanges = true }) {
            PlaceManagerView(draft: draft)
        }
        .sheet(isPresented: $showingTitleEditor) {
            TitleEditorSheet(title: $draft.title)
                .presentationDetents([.height(230)])
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

    private var actionBar: some View {
        HStack(spacing: 11) {
            Button {
                showingPlaces = true
            } label: {
                Label("장소 편집", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(MRSecondaryButtonStyle())

            Button {
                if !store.isUnlocked && freeExportConsumed {
                    showingPaywall = true
                } else {
                    showingExport = true
                }
            } label: {
                Label("저장 및 공유", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(MRPrimaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            MRSectionHeader(title: "템플릿", subtitle: "현재 사진으로 바로 미리봅니다")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BoardTemplate.allCases) { template in
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) { draft.template = template }
                        } label: {
                            TemplateChoiceCard(template: template, isSelected: draft.template == template)
                                .frame(width: 112)
                        }
                        .buttonStyle(MRPressableStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @MainActor
    private func saveDraftPreview() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let size = CGSize(width: 540, height: 960)
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

private struct TitleEditorSheet: View {
    @Binding var title: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("보드 제목").font(.title3.weight(.bold))
            TextField("보드 제목", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { dismiss() }
            Button("완료") { dismiss() }
                .buttonStyle(MRPrimaryButtonStyle())
        }
        .padding(20)
        .background(MRColor.background)
        .onAppear { focused = true }
    }
}

private struct TemplateChoiceCard: View {
    let template: BoardTemplate
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(template == .scrapbook ? Color(hex: 0xB98A58) : Color(hex: 0xEFE8DA))
                Image(systemName: template.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? MRColor.accent : MRColor.secondaryText)
                if template == .ribbon {
                    Capsule().fill(MRColor.accent.opacity(0.8)).frame(width: 52, height: 4).rotationEffect(.degrees(18))
                }
            }
            .frame(height: 70)
            Text(template.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? MRColor.accent : MRColor.primaryText)
        }
        .padding(8)
        .background(isSelected ? MRColor.accentSoft : MRColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? MRColor.accent : MRColor.border.opacity(0.55), lineWidth: isSelected ? 1.5 : 0.7)
        }
    }
}

enum ExportAction { case share, save }

struct ExportSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.story.rawValue
    let onExport: (UIImage, ExportAction) -> Void

    @State private var format: ExportFormat = .story
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("출력 비율", selection: $format) {
                    ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                    .aspectRatio(format.aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: .black.opacity(0.11), radius: 14, y: 7)
                    .frame(maxHeight: 500)

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(MRColor.background)
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 11) {
                    Button {
                        Task { if let image = await render() { onExport(image, .save) } }
                    } label: { Label("저장", systemImage: "square.and.arrow.down") }
                    .buttonStyle(MRSecondaryButtonStyle())

                    Button {
                        Task { if let image = await render() { onExport(image, .share) } }
                    } label: { Label("공유", systemImage: "square.and.arrow.up") }
                    .buttonStyle(MRPrimaryButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Divider() }
            }
            .overlay {
                if isRendering {
                    ZStack {
                        Color.black.opacity(0.08).ignoresSafeArea()
                        ProgressView("고화질 이미지 만드는 중")
                            .padding(22)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .onAppear {
                format = ExportFormat(rawValue: defaultFormat) ?? .story
            }
            .onChange(of: format) { _, newValue in
                defaultFormat = newValue.rawValue
            }
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
                Section {
                    ForEach($draft.places) { $place in
                        HStack(spacing: 10) {
                            NavigationLink {
                                PlaceEditorView(place: $place, draft: draft)
                            } label: {
                                HStack(spacing: 12) {
                                    AssetThumbnailView(identifier: place.representativeAssetIdentifier, size: CGSize(width: 58, height: 58))
                                        .frame(width: 58, height: 58)
                                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                        .opacity(place.isHidden ? 0.36 : 1)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.title).font(.subheadline.weight(.semibold))
                                        Text("사진 \(place.photoCount)장 · \(place.startDate.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(MRColor.secondaryText)
                                    }
                                }
                            }
                            Button {
                                place.isHidden.toggle()
                            } label: {
                                Image(systemName: place.isHidden ? "eye.slash" : "eye")
                                    .foregroundStyle(place.isHidden ? MRColor.secondaryText : MRColor.accent)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(place.isHidden ? "보드에 표시" : "보드에서 숨기기")
                        }
                    }
                    .onMove { source, destination in
                        draft.places.move(fromOffsets: source, toOffset: destination)
                    }
                } footer: {
                    Text("오른쪽 핸들을 끌어 방문 순서를 바꾸고, 눈 아이콘으로 표시 여부를 정합니다.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("장소와 사진")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(place.representativeAssetIdentifier == identifier ? MRColor.accent : .clear, lineWidth: 3)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if place.representativeAssetIdentifier == identifier {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(MRColor.accent)
                                            .background(Circle().fill(.white))
                                            .padding(6)
                                    }
                                }
                        }
                        .buttonStyle(MRPressableStyle())
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
        let boardRect = CGRect(
            x: size.width * 0.02,
            y: size.height * 0.015,
            width: size.width * 0.96,
            height: size.height * 0.97
        )
        let mapRect = boardRect.insetBy(dx: size.width * 0.025, dy: size.width * 0.025)

        return ZStack {
            CorkBoardTexture()
            RoundedRectangle(cornerRadius: size.width * 0.018, style: .continuous)
                .fill(Color(hex: 0xA97845))
                .frame(width: boardRect.width, height: boardRect.height)
                .position(x: boardRect.midX, y: boardRect.midY)
                .overlay(CorkBoardTexture().clipShape(RoundedRectangle(cornerRadius: size.width * 0.018)).frame(width: boardRect.width, height: boardRect.height))
                .shadow(color: .black.opacity(0.18), radius: size.width * 0.018, y: size.width * 0.012)

            mapPaper(in: mapRect)
            ropeLayer(in: mapRect, scale: 0.245)
            photoLayer(in: mapRect, scale: 0.245, labeled: true)
            pinLayer(in: mapRect, scale: 0.245)
            titleNote(in: mapRect)
            footer(in: mapRect, dark: true)
        }
    }

    private func editorial(in size: CGSize) -> some View {
        let mapRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.70)
        return ZStack(alignment: .top) {
            MRColor.paper
            VStack(spacing: 0) {
                ZStack {
                    mapPaper(in: mapRect)
                    ropeLayer(in: mapRect, scale: 0.17)
                    pinLayer(in: mapRect, scale: 0.17)
                }
                .frame(height: mapRect.height)
                HStack(spacing: size.width * 0.014) {
                    ForEach(Array(model.visiblePlaces.prefix(4))) { place in
                        if let image = model.photoImages[place.representativeAssetIdentifier] {
                            Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).clipped()
                        }
                    }
                }
                .frame(height: size.height * 0.22)
                .padding(size.width * 0.04)
            }
            genericHeader(size, dark: false)
            genericFooter(size, dark: false)
        }
    }

    private func postcard(in size: CGSize) -> some View {
        let mapRect = CGRect(x: size.width * 0.07, y: size.width * 0.07, width: size.width * 0.86, height: size.height - size.width * 0.14)
        return ZStack {
            MRColor.paperBright
            mapPaper(in: mapRect)
            ropeLayer(in: mapRect, scale: 0.18)
            photoLayer(in: mapRect, scale: 0.18, labeled: false)
            pinLayer(in: mapRect, scale: 0.18)
            genericHeader(size, dark: false)
            genericFooter(size, dark: false)
        }
    }

    private func scrapbook(in size: CGSize) -> some View {
        let boardRect = CGRect(x: size.width * 0.025, y: size.height * 0.018, width: size.width * 0.95, height: size.height * 0.965)
        let mapRect = boardRect.insetBy(dx: size.width * 0.04, dy: size.width * 0.04)
        return ZStack {
            Color(hex: 0xA97845)
            CorkBoardTexture()
            mapPaper(in: mapRect)
            ropeLayer(in: mapRect, scale: 0.245)
            photoLayer(in: mapRect, scale: 0.245, labeled: true)
            pinLayer(in: mapRect, scale: 0.245)
            titleNote(in: mapRect)
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(Color(hex: 0xD9C29D).opacity(0.78))
                    .frame(width: size.width * 0.17, height: size.height * 0.022)
                    .rotationEffect(.degrees(index == 1 ? -12 : 9))
                    .position(x: size.width * [0.20, 0.80, 0.57][index], y: size.height * [0.20, 0.46, 0.84][index])
            }
            footer(in: mapRect, dark: true)
        }
    }

    private func mapPaper(in rect: CGRect) -> some View {
        ZStack {
            Image(uiImage: model.mapImage)
                .resizable()
                .scaledToFill()
                .frame(width: rect.width, height: rect.height)
                .clipped()
            Color(hex: 0xF4EFE5).opacity(0.30)
            PaperGrain()
        }
        .frame(width: rect.width, height: rect.height)
        .clipShape(RoundedRectangle(cornerRadius: rect.width * 0.012, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: rect.width * 0.012)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: rect.width * 0.012, y: rect.width * 0.008)
        .position(x: rect.midX, y: rect.midY)
    }

    private func ropeLayer(in rect: CGRect, scale: CGFloat) -> some View {
        Canvas { context, _ in
            let points = routePoints(in: rect, scale: scale)
            let thickness = max(7, rect.width * 0.018)
            let rope = context.resolve(Image("RouteRopeRed"))
            let tileWidth = thickness * 4.0

            for segment in routeSegments(from: points) {
                let dx = segment.end.x - segment.start.x
                let dy = segment.end.y - segment.start.y
                let length = max(sqrt(dx * dx + dy * dy), thickness)
                let angle = Angle(radians: Double(atan2(dy, dx)))
                let midpoint = CGPoint(x: (segment.start.x + segment.end.x) * 0.5, y: (segment.start.y + segment.end.y) * 0.5)

                context.drawLayer { layer in
                    layer.translateBy(x: midpoint.x, y: midpoint.y)
                    layer.rotate(by: angle)
                    layer.addFilter(.shadow(color: .black.opacity(0.24), radius: thickness * 0.34, x: 0, y: thickness * 0.22))

                    let capsuleRect = CGRect(x: -length * 0.5 - thickness * 0.18, y: -thickness * 0.5, width: length + thickness * 0.36, height: thickness)
                    layer.clip(to: Capsule().path(in: capsuleRect))

                    var x = capsuleRect.minX - 1
                    while x < capsuleRect.maxX {
                        layer.draw(rope, in: CGRect(x: x, y: capsuleRect.minY, width: tileWidth + 1, height: thickness))
                        x += tileWidth
                    }
                }

                var highlight = Path()
                highlight.move(to: segment.start)
                highlight.addLine(to: segment.end)
                context.stroke(highlight, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: max(1, thickness * 0.16), lineCap: .round))
            }
        }
    }

    private func pinLayer(in rect: CGRect, scale: CGFloat) -> some View {
        let points = routePoints(in: rect, scale: scale)
        let pinWidth = max(28, rect.width * 0.074)
        let pinHeight = pinWidth * 1.60
        let assets = ["RoutePinBlue", "RoutePinTeal", "RoutePinYellow", "RoutePinCream", "RoutePinRed", "RoutePinGreen"]

        return ZStack {
            ForEach(points.indices, id: \.self) { index in
                Image(assets[index % assets.count])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: pinWidth, height: pinHeight)
                    .shadow(color: .black.opacity(0.24), radius: pinWidth * 0.09, y: pinWidth * 0.07)
                    .position(x: points[index].x, y: points[index].y - pinHeight * 0.34)
            }
        }
    }

    private func photoLayer(in rect: CGRect, scale: CGFloat, labeled: Bool) -> some View {
        let positions = cardPositions(count: model.visiblePlaces.count)
        return ZStack {
            ForEach(Array(model.visiblePlaces.enumerated()), id: \.element.id) { index, place in
                if index < positions.count, let image = model.photoImages[place.representativeAssetIdentifier] {
                    BoardPhotoCard(place: place, image: image, size: rect.size, scale: scale, labeled: labeled)
                        .rotationEffect(.degrees(cardRotationDegrees(for: index)))
                        .position(x: rect.minX + positions[index].x * rect.width, y: rect.minY + positions[index].y * rect.height)
                }
            }
        }
    }

    private func titleNote(in rect: CGRect) -> some View {
        let width = rect.width * 0.42
        return ZStack {
            VStack(alignment: .leading, spacing: rect.height * 0.003) {
                Text(model.date.mrBoardDate)
                    .font(.system(size: rect.width * 0.025, weight: .medium))
                    .foregroundStyle(MRColor.ink.opacity(0.68))
                Text(model.title)
                    .font(.system(size: rect.width * 0.052, weight: .bold))
                    .foregroundStyle(MRColor.ink)
                    .lineLimit(2)
                Text("사진으로 다시 엮은 하루")
                    .font(.system(size: rect.width * 0.022, weight: .medium))
                    .foregroundStyle(MRColor.ink.opacity(0.58))
            }
            .frame(width: width, alignment: .leading)
            .padding(rect.width * 0.025)
            .background(Color(hex: 0xFBF8F0))
            .overlay(PaperGrain().opacity(0.55))
            .rotationEffect(.degrees(-1.2))
            .shadow(color: .black.opacity(0.16), radius: rect.width * 0.012, y: rect.width * 0.008)
            .position(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.10)

            Image("RoutePinCream")
                .resizable()
                .scaledToFit()
                .frame(width: rect.width * 0.055, height: rect.width * 0.09)
                .position(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.045)
        }
    }

    private func genericHeader(_ size: CGSize, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: size.height * 0.004) {
            Text(model.date.mrBoardDate.uppercased())
                .font(.system(size: size.width * 0.032, weight: .semibold))
            Text(model.title)
                .font(.system(size: size.width * 0.070, weight: .bold, design: model.template == .postcard ? .serif : .default))
                .lineLimit(2)
        }
        .foregroundStyle(dark ? Color.black.opacity(0.82) : MRColor.ink)
        .padding(.horizontal, size.width * 0.065)
        .padding(.top, size.height * 0.05)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func genericFooter(_ size: CGSize, dark: Bool) -> some View {
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

    private func footer(in rect: CGRect, dark: Bool) -> some View {
        HStack {
            Text("사진 \(model.photoCount)장 · 장소 \(model.visiblePlaces.count)곳")
            Spacer()
            if watermark { Text("Made with MapRibbon") }
        }
        .font(.system(size: rect.width * 0.022, weight: .semibold))
        .foregroundStyle(dark ? Color.black.opacity(0.56) : MRColor.ink.opacity(0.62))
        .frame(width: rect.width * 0.88)
        .position(x: rect.midX, y: rect.maxY - rect.height * 0.025)
    }

    private func routePoints(in rect: CGRect, scale: CGFloat) -> [CGPoint] {
        switch model.template {
        case .ribbon, .scrapbook:
            return cardAnchorPoints(count: model.visiblePlaces.count, rect: rect, scale: scale)
        case .editorial, .postcard:
            return model.visiblePlaces.compactMap { place in
                guard let point = model.normalizedPoints[place.id] else { return nil }
                return CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            }
        }
    }

    private func cardAnchorPoints(count: Int, rect: CGRect, scale: CGFloat) -> [CGPoint] {
        let positions = cardPositions(count: count)
        let cardHeight = rect.width * scale * 1.34
        let topInset = cardHeight * 0.42
        return positions.enumerated().map { index, position in
            let center = CGPoint(x: rect.minX + position.x * rect.width, y: rect.minY + position.y * rect.height)
            let angle = cardRotationDegrees(for: index) * Double.pi / 180
            return CGPoint(x: center.x + CGFloat(sin(angle)) * topInset, y: center.y - CGFloat(cos(angle)) * topInset)
        }
    }

    private func cardRotationDegrees(for index: Int) -> Double {
        let values: [Double] = [-4, 3, -2, 4, -3, 2, -2, 3]
        return values[index % values.count]
    }

    private func routeSegments(from points: [CGPoint]) -> [BoardRouteSegment] {
        guard points.count > 1 else { return [] }
        return (0..<(points.count - 1)).map { BoardRouteSegment(id: $0, start: points[$0], end: points[$0 + 1]) }
    }

    private func cardPositions(count: Int) -> [CGPoint] {
        let all = [
            CGPoint(x: 0.25, y: 0.31), CGPoint(x: 0.74, y: 0.40),
            CGPoint(x: 0.24, y: 0.56), CGPoint(x: 0.30, y: 0.77),
            CGPoint(x: 0.73, y: 0.73), CGPoint(x: 0.22, y: 0.88),
            CGPoint(x: 0.52, y: 0.49), CGPoint(x: 0.52, y: 0.82)
        ]
        return Array(all.prefix(max(0, min(count, all.count))))
    }
}

private struct BoardPhotoCard: View {
    let place: BoardPlace
    let image: UIImage
    let size: CGSize
    let scale: CGFloat
    let labeled: Bool

    var body: some View {
        let width = size.width * scale
        let height = width * (labeled ? 1.34 : 1.08)
        ZStack {
            Rectangle().fill(Color.white.opacity(0.92))
                .frame(width: width, height: height)
                .offset(x: width * 0.065, y: height * 0.055)
            Rectangle().fill(Color.white.opacity(0.95))
                .frame(width: width, height: height)
                .offset(x: width * 0.035, y: height * 0.03)

            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.88, height: labeled ? height * 0.68 : height * 0.80)
                    .clipped()
                if labeled {
                    VStack(alignment: .leading, spacing: max(1, width * 0.012)) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(place.title)
                                .font(.system(size: width * 0.075, weight: .bold))
                                .lineLimit(1)
                            Spacer(minLength: 3)
                            Text("\(place.photoCount)장")
                                .font(.system(size: width * 0.060, weight: .bold))
                                .foregroundStyle(MRColor.accent)
                        }
                        Text(place.subtitle ?? place.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: width * 0.052, weight: .medium))
                            .foregroundStyle(MRColor.ink.opacity(0.65))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, width * 0.06)
                    .padding(.vertical, width * 0.045)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(hex: 0xFBFAF7))
                } else {
                    Rectangle().fill(.white).frame(maxHeight: .infinity)
                }
            }
            .padding(width * 0.055)
            .background(Color(hex: 0xFCFBF8))
            .frame(width: width, height: height)
        }
        .shadow(color: .black.opacity(0.20), radius: size.width * 0.014, y: size.width * 0.010)
    }
}

private struct CorkBoardTexture: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xA97845)))
            for index in 0..<360 {
                let x = CGFloat((index * 67) % 359) / 359 * size.width
                let y = CGFloat((index * 97) % 353) / 353 * size.height
                let radius = CGFloat(1 + index % 4)
                let shade = index % 3 == 0 ? Color.black.opacity(0.11) : Color.white.opacity(0.07)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius * 0.7)), with: .color(shade))
            }
        }
    }
}

private struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<120 {
                let x = CGFloat((index * 43) % 119) / 119 * size.width
                let y = CGFloat((index * 71) % 127) / 127 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(.black.opacity(0.025)))
            }
            for index in 0..<18 {
                let y = size.height * CGFloat(index + 1) / 19
                context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.3)), with: .color(.white.opacity(0.10)), lineWidth: 0.3)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SavedBoardDetailView: View {
    let board: SavedBoard
    @State private var showingActivity = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let image = UIImage(data: board.previewImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

                    HStack(spacing: 10) {
                        Label("사진 \(board.photoCount)장", systemImage: "photo.stack")
                        Label("장소 \(board.placeCount)곳", systemImage: "mappin.and.ellipse")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button { showingActivity = true } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
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
