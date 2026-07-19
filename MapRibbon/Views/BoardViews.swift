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
    @AppStorage("defaultExportFormat") private var defaultFormat = ExportFormat.poster.rawValue
    let onExport: (UIImage, ExportAction) -> Void

    @State private var format: ExportFormat = .poster
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
                format = ExportFormat(rawValue: defaultFormat) ?? .poster
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

enum BoardRouteLayout {
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
            ropeLayer(in: mapRect, scale: 0.215)
            photoLayer(in: mapRect, scale: 0.215, labeled: true)
            pinLayer(in: mapRect, scale: 0.215)
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
            Color(hex: 0xF4EFE5).opacity(0.18)
            PaperGrain().opacity(0.72)
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
    }

    private func pinLayer(in rect: CGRect, scale: CGFloat) -> some View {
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
    }

    private func photoLayer(in rect: CGRect, scale: CGFloat, labeled: Bool) -> some View {
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
    }

    private func titleNote(in rect: CGRect) -> some View {
        let width = rect.width * 0.40
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
            .position(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.095)

            Image("RoutePinCream")
                .resizable()
                .scaledToFit()
                .frame(width: rect.width * 0.055, height: rect.width * 0.09)
                .position(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.043)
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
        let cardHeight = rect.width * scale * 1.23
        let topInset = cardHeight * 0.42
        return positions.enumerated().map { index, position in
            let center = CGPoint(x: rect.minX + position.x * rect.width, y: rect.minY + position.y * rect.height)
            let angle = cardRotationDegrees(for: index) * Double.pi / 180
            return CGPoint(x: center.x + CGFloat(sin(angle)) * topInset, y: center.y - CGFloat(cos(angle)) * topInset)
        }
    }

    private func cardRotationDegrees(for index: Int) -> Double {
        let values: [Double] = [-2, 3, -2, 2, 4, -2, 2, -3]
        return values[index % values.count]
    }

    private func routeSegments(from points: [CGPoint]) -> [BoardRouteSegment] {
        BoardRouteLayout.edgePairs(for: points.count).enumerated().compactMap { index, pair in
            guard points.indices.contains(pair.0), points.indices.contains(pair.1) else { return nil }
            return BoardRouteSegment(id: index, start: points[pair.0], end: points[pair.1])
        }
    }

    private func cardPositions(count: Int) -> [CGPoint] {
        let all = [
            CGPoint(x: 0.245, y: 0.285), CGPoint(x: 0.760, y: 0.400),
            CGPoint(x: 0.240, y: 0.565), CGPoint(x: 0.300, y: 0.820),
            CGPoint(x: 0.740, y: 0.745), CGPoint(x: 0.215, y: 0.900),
            CGPoint(x: 0.520, y: 0.500), CGPoint(x: 0.525, y: 0.845)
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
}

private struct CorkBoardTexture: View {
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
