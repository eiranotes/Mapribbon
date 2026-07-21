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
            .background(MRScreenBackground())
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
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 9) {
                MREyebrow(text: "Day Route — Weaving")
                Text("하루를 엮는 중")
                    .font(MRType.display(27))
                    .foregroundStyle(MRColor.primaryText)
                Text(step.title)
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
            }
            MRRouteProgress(progress: progress)
                .padding(.horizontal, 34)
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
            .mrPlate(padding: 18)
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
    @Environment(AppRouter.self) private var router

    @State private var showingPlaces = false
    @State private var showingExport = false
    @State private var showingPaywall = false
    @State private var showingTitleEditor = false
    @State private var showingTemplatePicker = false
    @State private var showingThreadColorPicker = false
    @State private var showingCloseConfirmation = false
    @State private var exportedImage: UIImage?
    @State private var showingActivity = false
    @State private var saveNotice: BoardSaveNotice?
    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @AppStorage("freeExportConsumed") private var freeExportConsumed = false

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(180, proxy.size.width - 28)
            let heightConstrainedWidth = max(180, (proxy.size.height - 64) * 0.75)
            let boardWidth = min(availableWidth, heightConstrainedWidth)
            let visiblePlaces = draft.places.filter { !$0.isHidden }
            let photoCount = visiblePlaces.reduce(0) { $0 + $1.photoCount }

            VStack(spacing: 12) {
                Spacer(minLength: 8)

                BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                    .frame(width: boardWidth, height: boardWidth * 4.0 / 3.0)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { MRPlateFrame(cornerRadius: 16) }
                    .shadow(color: .black.opacity(0.13), radius: 15, y: 8)

                HStack(spacing: 10) {
                    Label(draft.template.title, systemImage: draft.template.symbolName)
                    Spacer(minLength: 8)
                    Text("\(visiblePlaces.count)곳 · 사진 \(photoCount)장")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 12)
                .frame(width: boardWidth, height: 40)
                .background(MRColor.surface.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(MRColor.frameInk.opacity(0.32), lineWidth: 0.8)
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MRScreenBackground())
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
                    Button {
                        showingThreadColorPicker = true
                    } label: {
                        Label("실 색상", systemImage: "paintpalette.fill")
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
        .sheet(isPresented: $showingThreadColorPicker) {
            ThreadColorPickerSheet(draft: draft)
                .presentationDetents([.height(270)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(draft: draft) { image, action in
                exportedImage = image
                if !store.isUnlocked { freeExportConsumed = true }
                let outcome = persist(image)
                hasUnsavedChanges = false
                switch action {
                case .share:
                    showingExport = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showingActivity = true }
                case .save:
                    Task {
                        do {
                            try await PhotoSaveService.save(image)
                            saveNotice = BoardSaveNotice(message: BoardCopy.savedMessage, outcome: outcome)
                        } catch {
                            saveNotice = BoardSaveNotice(message: error.localizedDescription, outcome: nil)
                        }
                    }
                }
            }
        }

        .sheet(isPresented: $showingActivity) {
            if let exportedImage { ActivityView(items: [exportedImage]) }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .overlay(alignment: .bottom) {
            if let saveNotice {
                BoardSaveToast(
                    notice: saveNotice,
                    onAtlas: {
                        router.selectedTab = .atlas
                        showingExport = false
                        self.saveNotice = nil
                        onClose()
                    },
                    onDismiss: { self.saveNotice = nil }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.22), value: saveNotice != nil)

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
        .onChange(of: draft.threadColor) { _, _ in hasUnsavedChanges = true }
        .onChange(of: draft.places) { _, _ in hasUnsavedChanges = true }
    }

    private var editorToolBar: some View {
        HStack(alignment: .top, spacing: 0) {
            BoardEditorToolButton(title: "장소·사진", symbol: "photo.on.rectangle.angled") {
                showingPlaces = true
            }

            BoardEditorToolButton(title: "템플릿", symbol: "square.stack.3d.up") {
                showingTemplatePicker = true
            }

            BoardEditorToolButton(title: "실 색상", symbol: "paintpalette.fill") {
                showingThreadColorPicker = true
            }

            BoardEditorToolButton(title: "저장·공유", symbol: "square.and.arrow.up") {
                presentExport()
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 12)
        .padding(.bottom, 8)
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
            _ = persist(image)
            hasUnsavedChanges = false
        }
    }

    private func persist(_ image: UIImage) -> BoardSaveOutcome? {
        guard let previewData = image.jpegData(compressionQuality: 0.88),
              let payloadData = try? JSONEncoder().encode(
                BoardArchivePayload(date: draft.date, title: draft.title, places: draft.places, template: draft.template, threadColor: draft.threadColor)
              ) else { return nil }

        let beforeBoards = (try? modelContext.fetch(FetchDescriptor<SavedBoard>())) ?? []
        let previouslyVisited = Set(beforeBoards.flatMap(\.regionKeys))
        let regions = BoardRegionSummary.regionKeys(from: draft.places)
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

        let afterBoards = (try? modelContext.fetch(FetchDescriptor<SavedBoard>())) ?? []
        let visited = Set(afterBoards.flatMap(\.regionKeys))
        guard let primaryRegion = BoardRegionSummary.primaryRegion(from: draft.places) else { return nil }
        let regionBoardCount = afterBoards.filter { $0.regionKeys.contains(primaryRegion) }.count
        let totalRegions = primaryRegion.hasPrefix("일본:") ? 8 : KoreaRegion.all.count
        return BoardSaveOutcome(
            regionKey: primaryRegion,
            regionBoardCount: regionBoardCount,
            visitedCount: visited.filter { primaryRegion.hasPrefix("일본:") ? $0.hasPrefix("일본:") : !$0.hasPrefix("일본:") }.count,
            totalRegionCount: totalRegions,
            isNewRegion: !previouslyVisited.contains(primaryRegion)
        )
    }
}

enum BoardRegionSummary {
    static func regionKeys(from places: [BoardPlace]) -> [String] {
        var seen = Set<String>()
        return places
            .filter { !$0.isHidden }
            .compactMap { RegionNormalizer.key(from: $0.administrativeArea) }
            .filter { seen.insert($0).inserted }
    }

    static func primaryRegion(from places: [BoardPlace]) -> String? {
        regionKeys(from: places).first
    }
}

private struct BoardSaveOutcome {
    let regionKey: String
    let regionBoardCount: Int
    let visitedCount: Int
    let totalRegionCount: Int
    let isNewRegion: Bool

    var displayRegion: String {
        regionKey.replacingOccurrences(of: "일본:", with: "")
    }

    var summary: String {
        BoardCopy.atlasProgress(
            region: displayRegion,
            boardCount: regionBoardCount,
            visitedCount: visitedCount,
            totalCount: totalRegionCount,
            isNewRegion: isNewRegion
        )
    }
}

private struct BoardSaveNotice {
    let message: String
    let outcome: BoardSaveOutcome?
}

private struct BoardSaveToast: View {
    let notice: BoardSaveNotice
    let onAtlas: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notice.outcome == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(notice.outcome == nil ? MRColor.warning : MRColor.success)

            VStack(alignment: .leading, spacing: 3) {
                Text(notice.message)
                    .font(.subheadline.weight(.semibold))
                if let outcome = notice.outcome {
                    Text(outcome.summary)
                        .font(.caption)
                        .foregroundStyle(MRColor.secondaryText)
                }
            }

            Spacer(minLength: 4)

            if notice.outcome != nil {
                Button("아틀라스 보기", action: onAtlas)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MRColor.accent)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(MRColor.border.opacity(0.55), lineWidth: 0.7) }
        .shadow(color: .black.opacity(0.14), radius: 16, y: 7)
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

private struct ThreadColorPickerSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(BoardThreadColor.allCases) { color in
                    Button {
                        draft.threadColor = color
                    } label: {
                        VStack(spacing: 9) {
                            ZStack {
                                Circle().fill(Color(hex: color.primaryHex)).frame(width: 48, height: 48)
                                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                                if draft.threadColor == color {
                                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            Text(color.title).font(.caption.weight(.semibold))
                                .foregroundStyle(draft.threadColor == color ? MRColor.accent : MRColor.primaryText)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(draft.threadColor == color ? MRColor.accentSoft : MRColor.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(draft.threadColor == color ? MRColor.accent : MRColor.border.opacity(0.5), lineWidth: draft.threadColor == color ? 1.4 : 0.7)
                        }
                    }
                    .buttonStyle(MRPressableStyle())
                    .accessibilityLabel("실 색상 \(color.title)")
                    .accessibilityAddTraits(draft.threadColor == color ? .isSelected : [])
                }
            }
            .padding(20).background(MRColor.background)
            .navigationTitle("실 색상").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: format)

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
                TextField("설명", text: Binding($place.caption, replacingNilWith: ""))
                if let addressSummary = place.addressSummary, !addressSummary.isEmpty {
                    LabeledContent("위치", value: addressSummary)
                        .foregroundStyle(MRColor.secondaryText)
                }
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
        guard count > 1 else { return [] }
        return (0..<(count - 1)).map { ($0, $0 + 1) }
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
            board(in: proxy.size)
        }
        .background(Color(hex: 0x8A5A32))
        .clipped()
    }

    private func board(in size: CGSize) -> some View {
        let outer = CGRect(origin: .zero, size: size)
        let mapRect = outer.insetBy(dx: max(10, size.width * 0.035), dy: max(9, size.width * 0.030))
        let places = model.visiblePlaces
        let targetAspectRatio = size.width / max(1, size.height)
        let geoPoints: [CGPoint]? = {
            let points = places.compactMap { model.normalizedPoints[$0.id] }
            guard points.count == places.count else { return nil }
            return BoardLayoutEngine.adjustedForAspectFill(
                points,
                sourceAspectRatio: 3.0 / 4.0,
                targetAspectRatio: targetAspectRatio
            )
        }()
        let placements = BoardLayoutEngine.placements(
            count: places.count,
            geoPoints: geoPoints,
            aspectRatio: targetAspectRatio
        )
        let anchors = BoardLayoutEngine.anchorPoints(placements: placements, in: mapRect)

        return ZStack {
            CorkBoardBackground(template: model.template)

            PaperMapSheet(mapImage: model.mapImage, template: model.template)
                .frame(width: mapRect.width, height: mapRect.height)
                .position(x: mapRect.midX, y: mapRect.midY)

            photoCards(places: places, placements: placements, in: mapRect)
            ThreadLayer(anchors: anchors, color: model.threadColor, width: mapRect.width)
            PushPinLayer(anchors: anchors, width: mapRect.width)

            TitleNoteView(title: model.title, date: model.date, width: mapRect.width * 0.42)
                .position(
                    x: mapRect.minX + mapRect.width * 0.055 + mapRect.width * 0.21,
                    y: mapRect.minY + mapRect.height * 0.030 + mapRect.width * 0.42 * 0.21
                )

            if watermark {
                Text("Made with MapRibbon")
                    .font(.system(size: max(9, mapRect.width * 0.019), weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3A3428).opacity(0.58))
                    .padding(.horizontal, mapRect.width * 0.016)
                    .padding(.vertical, mapRect.width * 0.008)
                    .background(Color(hex: 0xFCF8EE).opacity(0.74), in: Capsule())
                    .position(x: mapRect.maxX - mapRect.width * 0.125, y: mapRect.maxY - mapRect.width * 0.035)
            }
        }
    }

    @ViewBuilder
    private func photoCards(places: [BoardPlace], placements: [BoardCardPlacement], in rect: CGRect) -> some View {
        ZStack {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                if index < placements.count {
                    let placement = placements[index]
                    PolaroidStackCard(
                        place: place,
                        image: model.photoImages[place.representativeAssetIdentifier],
                        width: rect.width * placement.widthFactor,
                        rotation: placement.rotation,
                        variant: index,
                        template: model.template
                    )
                    .position(
                        x: rect.minX + rect.width * placement.center.x,
                        y: rect.minY + rect.height * placement.center.y
                    )
                }
            }
        }
    }
}

struct BoardCardPlacement: Equatable {
    let center: CGPoint
    let widthFactor: CGFloat
    let rotation: Double
}

enum BoardLayoutEngine {
    static let cardHeightRatio: CGFloat = 1.24
    static let maxGeoDisplacement: CGFloat = 0.22

    static func widthFactor(forAspectRatio aspectRatio: CGFloat) -> CGFloat {
        if aspectRatio < 0.64 { return 0.29 }
        if aspectRatio < 0.78 { return 0.262 }
        return 0.252
    }

    static func cardPlacements(for count: Int, aspectRatio: CGFloat) -> [BoardCardPlacement] {
        placements(count: count, geoPoints: nil, aspectRatio: aspectRatio)
    }

    static func adjustedForAspectFill(
        _ points: [CGPoint],
        sourceAspectRatio: CGFloat,
        targetAspectRatio: CGFloat
    ) -> [CGPoint] {
        guard sourceAspectRatio > 0, targetAspectRatio > 0 else { return points }
        return points.map { point in
            var adjusted = point
            if sourceAspectRatio > targetAspectRatio {
                let scale = sourceAspectRatio / targetAspectRatio
                adjusted.x = point.x * scale - (scale - 1) / 2
            } else if sourceAspectRatio < targetAspectRatio {
                let scale = targetAspectRatio / sourceAspectRatio
                adjusted.y = point.y * scale - (scale - 1) / 2
            }
            adjusted.x = min(0.98, max(0.02, adjusted.x))
            adjusted.y = min(0.98, max(0.02, adjusted.y))
            return adjusted
        }
    }

    private static let fallbackSeeds: [CGPoint] = [
        CGPoint(x: 0.28, y: 0.30), CGPoint(x: 0.74, y: 0.26),
        CGPoint(x: 0.30, y: 0.55), CGPoint(x: 0.72, y: 0.58),
        CGPoint(x: 0.30, y: 0.82), CGPoint(x: 0.72, y: 0.84),
        CGPoint(x: 0.51, y: 0.44), CGPoint(x: 0.51, y: 0.70)
    ]

    static func placements(count: Int, geoPoints: [CGPoint]?, aspectRatio: CGFloat) -> [BoardCardPlacement] {
        guard count > 0 else { return [] }
        let cardWidth = widthFactor(forAspectRatio: aspectRatio)
        if count == 1 {
            return [BoardCardPlacement(center: CGPoint(x: 0.5, y: 0.56), widthFactor: min(0.46, cardWidth * 1.6), rotation: -1.2)]
        }

        let cardHeight = cardWidth * cardHeightRatio * aspectRatio
        let candidateSeeds = geoPoints?.count == count ? geoPoints! : []
        let spanX = (candidateSeeds.map(\.x).max() ?? 0) - (candidateSeeds.map(\.x).min() ?? 0)
        let spanY = (candidateSeeds.map(\.y).max() ?? 0) - (candidateSeeds.map(\.y).min() ?? 0)
        let useGeography = candidateSeeds.count == count && !(spanX < 0.02 && spanY < 0.02)
        let seeds = useGeography ? candidateSeeds : (0..<count).map { fallbackSeeds[$0 % fallbackSeeds.count] }

        var points = relaxed(
            seeds: seeds,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            preserveGeography: useGeography
        )
        if hasLayoutConflict(points, cardWidth: cardWidth, cardHeight: cardHeight) {
            points = relaxed(
                seeds: (0..<count).map { fallbackSeeds[$0 % fallbackSeeds.count] },
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                preserveGeography: false
            )
        }

        let rotations: [Double] = [-2.4, 2.6, -1.8, 1.6, 2.8, -2.0, 1.2, -2.6]
        return points.enumerated().map { index, point in
            BoardCardPlacement(center: point, widthFactor: cardWidth, rotation: rotations[index % rotations.count])
        }
    }

    private static func relaxed(
        seeds: [CGPoint],
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        preserveGeography: Bool
    ) -> [CGPoint] {
        let marginX = cardWidth * 0.5 + 0.035
        let marginTop = cardHeight * 0.5 + 0.035
        let marginBottom = cardHeight * 0.5 + 0.045
        let origins = seeds.enumerated().map { index, seed in
            CGPoint(
                x: min(1 - marginX, max(marginX, seed.x + CGFloat(sin(Double(index) * 2.39996)) * 0.006)),
                y: min(1 - marginBottom, max(marginTop, seed.y + CGFloat(cos(Double(index) * 2.39996)) * 0.006))
            )
        }
        var points = origins
        let titleMaxX: CGFloat = 0.52
        let titleMaxY: CGFloat = 0.140 + cardHeight * 0.92
        let minDX = cardWidth * 0.92
        let minDY = cardHeight * 0.90

        for _ in 0..<240 {
            for index in points.indices {
                var point = points[index]
                if point.x < titleMaxX && point.y < titleMaxY {
                    if (titleMaxY - point.y) < (titleMaxX - point.x) {
                        point.y = titleMaxY
                    } else {
                        point.x = titleMaxX
                    }
                    points[index] = point
                }
            }

            for i in points.indices {
                for j in points.indices where j > i {
                    let dx = points[j].x - points[i].x
                    let dy = points[j].y - points[i].y
                    let overlapX = minDX - abs(dx)
                    let overlapY = minDY - abs(dy)
                    guard overlapX > 0, overlapY > 0 else { continue }
                    if overlapX / minDX < overlapY / minDY {
                        let sign: CGFloat = dx == 0 ? ((j - i).isMultiple(of: 2) ? -1 : 1) : (dx > 0 ? 1 : -1)
                        let shift = (overlapX / 2 + 0.002) * sign
                        points[i].x -= shift
                        points[j].x += shift
                    } else {
                        let sign: CGFloat = dy == 0 ? ((j - i).isMultiple(of: 2) ? -1 : 1) : (dy > 0 ? 1 : -1)
                        let shift = (overlapY / 2 + 0.002) * sign
                        points[i].y -= shift
                        points[j].y += shift
                    }
                }
            }

            for index in points.indices {
                if preserveGeography {
                    points[index].x += (origins[index].x - points[index].x) * 0.045
                    points[index].y += (origins[index].y - points[index].y) * 0.045
                    let dx = points[index].x - origins[index].x
                    let dy = points[index].y - origins[index].y
                    let distance = hypot(dx, dy)
                    if distance > maxGeoDisplacement {
                        let scale = maxGeoDisplacement / distance
                        points[index] = CGPoint(x: origins[index].x + dx * scale, y: origins[index].y + dy * scale)
                    }
                }
                points[index].x = min(1 - marginX, max(marginX, points[index].x))
                points[index].y = min(1 - marginBottom, max(marginTop, points[index].y))
                if points[index].x < titleMaxX && points[index].y < titleMaxY {
                    if (titleMaxY - points[index].y) < (titleMaxX - points[index].x) {
                        points[index].y = titleMaxY
                    } else {
                        points[index].x = titleMaxX
                    }
                }
            }
        }
        return points
    }

    private static func hasLayoutConflict(_ points: [CGPoint], cardWidth: CGFloat, cardHeight: CGFloat) -> Bool {
        let minDX = cardWidth * 0.92
        let minDY = cardHeight * 0.90
        let titleMaxX: CGFloat = 0.52
        let titleMaxY: CGFloat = 0.140 + cardHeight * 0.92
        for point in points where point.x < titleMaxX && point.y < titleMaxY { return true }
        for i in points.indices {
            for j in points.indices where j > i {
                if abs(points[j].x - points[i].x) < minDX - 0.005,
                   abs(points[j].y - points[i].y) < minDY - 0.005 {
                    return true
                }
            }
        }
        return false
    }

    static func anchorPoints(placements: [BoardCardPlacement], in rect: CGRect) -> [CGPoint] {
        placements.map { placement in
            let width = rect.width * placement.widthFactor
            let height = width * cardHeightRatio
            let inset = height * 0.44
            let angle = placement.rotation * Double.pi / 180
            let center = CGPoint(
                x: rect.minX + rect.width * placement.center.x,
                y: rect.minY + rect.height * placement.center.y
            )
            return CGPoint(x: center.x + CGFloat(sin(angle)) * inset, y: center.y - CGFloat(cos(angle)) * inset)
        }
    }
}

private struct PolaroidStackCard: View {
    let place: BoardPlace
    let image: UIImage?
    let width: CGFloat
    let rotation: Double
    let variant: Int
    let template: BoardTemplate

    private var cardColor: Color {
        switch template {
        case .editorial: return Color(hex: 0xFAF9F5)
        case .postcard: return Color(hex: 0xF4E6C8)
        case .scrapbook: return Color(hex: 0xFFFDF7)
        case .ribbon: return Color(hex: 0xFDFBF4)
        }
    }

    var body: some View {
        let height = width * BoardLayoutEngine.cardHeightRatio
        let direction: Double = variant.isMultiple(of: 2) ? 1 : -1
        ZStack {
            if template != .editorial {
                Rectangle()
                    .fill(template == .postcard ? Color(hex: 0xDDC79F) : Color(hex: 0xEFEADD))
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(rotation + 2.6 * direction))
                    .offset(x: width * 0.055 * direction, y: height * 0.045)
                    .shadow(color: Color(hex: 0x190C02).opacity(0.30), radius: width * 0.012, y: width * 0.006)
                Rectangle()
                    .fill(template == .postcard ? Color(hex: 0xE9D8B5) : Color(hex: 0xF6F2E7))
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(rotation - 1.6 * direction))
                    .offset(x: -width * 0.03 * direction, y: height * 0.024)
                    .shadow(color: Color(hex: 0x190C02).opacity(0.24), radius: width * 0.010, y: width * 0.005)
            }
            topCard(height: height)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color(hex: 0x190C02).opacity(0.38), radius: width * 0.018, y: width * 0.009)
        }
    }

    private func topCard(height: CGFloat) -> some View {
        let pad = width * 0.055
        let photoWidth = width - pad * 2
        let photoHeight = photoWidth * 0.86
        return VStack(alignment: .leading, spacing: 0) {
            photoView(width: photoWidth, height: photoHeight)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(place.title)
                    .font(.system(size: width * 0.074, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2A261E))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Spacer(minLength: 2)
                Text(BoardCopy.photoCount(place.photoCount))
                    .font(.system(size: width * 0.056, weight: .bold))
                    .foregroundStyle(Color(hex: 0xB03A2E))
            }
            .padding(.top, width * 0.052)
            Text(place.boardCaptionText)
                .font(.system(size: width * 0.050, weight: .medium))
                .foregroundStyle(Color(hex: 0x3A3428).opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .padding(.top, width * 0.026)
            Spacer(minLength: 0)
        }
        .padding(pad)
        .frame(width: width, height: height, alignment: .top)
        .background(cardColor)
        .overlay { Rectangle().stroke(Color.black.opacity(0.06), lineWidth: max(0.5, width * 0.0022)) }
    }

    @ViewBuilder
    private func photoView(width photoWidth: CGFloat, height photoHeight: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                MRPhotoPlaceholder()
            }
        }
        .frame(width: photoWidth, height: photoHeight)
        .clipped()
        .overlay { Rectangle().stroke(Color.black.opacity(0.10), lineWidth: max(0.5, width * 0.0022)) }
    }
}

extension BoardPlace {
    var boardTimeRangeText: String {
        let start = startDate.formatted(date: .omitted, time: .shortened)
        let end = endDate.formatted(date: .omitted, time: .shortened)
        return start == end ? start : "\(start)–\(end)"
    }

    var boardCaptionText: String {
        if let caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return caption }
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return subtitle }
        return boardTimeRangeText
    }
}

private enum BoardCopy {
    static var savedMessage: String {
        NSLocalizedString("board.saved", value: "사진 보관함에 저장했습니다.", comment: "Board export saved")
    }

    static func photoCount(_ count: Int) -> String {
        String(format: NSLocalizedString("board.photo_count", value: "%d장", comment: "Photo count on a board card"), count)
    }

    static func atlasProgress(
        region: String,
        boardCount: Int,
        visitedCount: Int,
        totalCount: Int,
        isNewRegion: Bool
    ) -> String {
        let key = isNewRegion ? "board.atlas_progress_new" : "board.atlas_progress"
        let fallback = isNewRegion ? "%@ 첫 기록 · %d/%d 지역" : "%@ %d번째 기록 · %d/%d 지역"
        if isNewRegion {
            return String(format: NSLocalizedString(key, value: fallback, comment: "Atlas progress after saving a new region"), region, visitedCount, totalCount)
        }
        return String(format: NSLocalizedString(key, value: fallback, comment: "Atlas progress after saving a board"), region, boardCount, visitedCount, totalCount)
    }

    static func seasonPhrase(month: Int) -> String {
        let key: String
        let fallback: String
        switch month {
        case 3...5:
            key = "board.season.spring"
            fallback = "사진으로 다시 엮은 봄의 하루"
        case 6...8:
            key = "board.season.summer"
            fallback = "사진으로 다시 엮은 여름의 하루"
        case 9...11:
            key = "board.season.autumn"
            fallback = "사진으로 다시 엮은 가을의 하루"
        default:
            key = "board.season.winter"
            fallback = "사진으로 다시 엮은 겨울의 하루"
        }
        return NSLocalizedString(key, value: fallback, comment: "Seasonal board subtitle")
    }
}

extension Date {
    var mrSeasonPhrase: String {
        BoardCopy.seasonPhrase(month: Calendar.current.component(.month, from: self))
    }
}

private struct TitleNoteView: View {
    let title: String
    let date: Date
    let width: CGFloat

    var body: some View {
        let height = width * 0.42
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: height * 0.065) {
                Text(date.mrBoardDate)
                    .font(.system(size: width * 0.062, weight: .medium))
                    .foregroundStyle(Color(hex: 0x3C3426).opacity(0.72))
                Text(title)
                    .font(.system(size: width * 0.125, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2A261E))
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                Text(date.mrSeasonPhrase)
                    .font(.system(size: width * 0.058, weight: .medium))
                    .foregroundStyle(Color(hex: 0x3C3426).opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(.horizontal, width * 0.075)
            .frame(width: width, height: height, alignment: .leading)
            .background(Color(hex: 0xFCF8EE))
            .overlay { Rectangle().stroke(Color.black.opacity(0.045), lineWidth: 1) }
            .rotationEffect(.degrees(-1.1))
            .shadow(color: Color(hex: 0x190C02).opacity(0.35), radius: width * 0.020, y: width * 0.010)

            BrassPin(diameter: width * 0.034)
                .offset(y: -width * 0.006)
        }
        .frame(width: width, height: height)
    }
}

private struct BrassPin: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x140800).opacity(0.30))
                .frame(width: diameter * 1.1, height: diameter * 0.55)
                .offset(x: diameter * 0.28, y: diameter * 0.52)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xE8D3A0), Color(hex: 0x7A5C22)],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: diameter * 0.05,
                        endRadius: diameter * 0.72
                    )
                )
                .frame(width: diameter, height: diameter)
        }
    }
}

private struct ThreadLayer: View {
    let anchors: [CGPoint]
    let color: BoardThreadColor
    let width: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard anchors.count > 1 else { return }
            let mainWidth = max(2.6, width * 0.0058)
            let primary = Color(hex: color.primaryHex)
            let highlight = Color(hex: color.highlightHex)
            let dash: [CGFloat] = [mainWidth * 0.50, mainWidth * 0.73]

            for index in 0..<(anchors.count - 1) {
                let start = anchors[index]
                let end = anchors[index + 1]
                let length = hypot(end.x - start.x, end.y - start.y)
                let sag = min(width * 0.042, length * 0.085)
                let control = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 + sag)

                var path = Path()
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)

                var shadowPath = Path()
                shadowPath.move(to: CGPoint(x: start.x, y: start.y + mainWidth * 0.5))
                shadowPath.addQuadCurve(
                    to: CGPoint(x: end.x, y: end.y + mainWidth * 0.5),
                    control: CGPoint(x: control.x, y: control.y + mainWidth * 0.7)
                )
                context.stroke(
                    shadowPath,
                    with: .color(Color(hex: 0x1E0A02).opacity(0.25)),
                    style: StrokeStyle(lineWidth: mainWidth * 1.27, lineCap: .round)
                )
                context.stroke(path, with: .color(primary), style: StrokeStyle(lineWidth: mainWidth, lineCap: .round))
                context.stroke(
                    path,
                    with: .color(highlight.opacity(0.60)),
                    style: StrokeStyle(lineWidth: mainWidth * 0.33, lineCap: .round, dash: dash, dashPhase: CGFloat(index) * 2)
                )
                context.stroke(
                    path,
                    with: .color(.black.opacity(0.30)),
                    style: StrokeStyle(lineWidth: mainWidth * 0.29, lineCap: .round, dash: dash, dashPhase: CGFloat(index) * 2 + dash[0])
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PushPinLayer: View {
    let anchors: [CGPoint]
    let width: CGFloat

    private static let palette: [(UInt, UInt)] = [
        (0x4D79C7, 0x1D3F7A), (0x37A695, 0x146457), (0xE5C04B, 0x96731A),
        (0xF0EDE4, 0x9A9384), (0xD6493A, 0x7E1D14), (0x5DA258, 0x2C6430)
    ]

    var body: some View {
        Canvas { context, _ in
            let radius = max(7, width * 0.015)
            for (index, anchor) in anchors.enumerated() {
                drawPin(context, at: anchor, radius: radius, palette: Self.palette[index % Self.palette.count])
            }
        }
        .allowsHitTesting(false)
    }

    private func drawPin(_ context: GraphicsContext, at point: CGPoint, radius: CGFloat, palette: (UInt, UInt)) {
        let lite = Color(hex: palette.0)
        let dark = Color(hex: palette.1)

        let shadowRect = CGRect(
            x: point.x + radius * 0.22 - radius * 0.8,
            y: point.y + radius * 0.52 - radius * 0.4,
            width: radius * 1.6,
            height: radius * 0.8
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color(hex: 0x140800).opacity(0.30)))

        var needle = Path()
        needle.move(to: CGPoint(x: point.x, y: point.y - radius * 0.15))
        needle.addLine(to: CGPoint(x: point.x + radius * 0.19, y: point.y + radius * 0.44))
        context.stroke(needle, with: .color(Color(hex: 0x8D8D92)), style: StrokeStyle(lineWidth: max(1.2, radius * 0.16), lineCap: .round))

        let ballCenter = CGPoint(x: point.x, y: point.y - radius * 0.9)
        let ballRect = CGRect(x: ballCenter.x - radius, y: ballCenter.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: ballRect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: lite, location: 0.18),
                    .init(color: dark, location: 1)
                ]),
                center: CGPoint(x: ballCenter.x - radius * 0.38, y: ballCenter.y - radius * 0.42),
                startRadius: radius * 0.1,
                endRadius: radius * 1.5
            )
        )

        let flangeRect = CGRect(x: point.x - radius * 0.62, y: point.y - radius * 0.26, width: radius * 1.24, height: radius * 0.60)
        context.fill(
            Path(ellipseIn: flangeRect),
            with: .linearGradient(
                Gradient(colors: [dark, lite, dark]),
                startPoint: CGPoint(x: flangeRect.minX, y: flangeRect.midY),
                endPoint: CGPoint(x: flangeRect.maxX, y: flangeRect.midY)
            )
        )
    }
}

private struct PaperMapSheet: View {
    let mapImage: UIImage
    let template: BoardTemplate

    private var baseHex: UInt {
        switch template {
        case .editorial: return 0xF2F0EA
        case .postcard: return 0xE7D1A4
        case .scrapbook: return 0xF2E9D6
        case .ribbon: return 0xEDE7D8
        }
    }

    private var multiplyHex: UInt {
        switch template {
        case .editorial: return 0xF6F3EA
        case .postcard: return 0xE8C992
        case .scrapbook: return 0xF2DEC0
        case .ribbon: return 0xF0E5CA
        }
    }

    private var saturation: Double {
        switch template {
        case .editorial: return 0.48
        case .postcard: return 0.54
        case .scrapbook: return 0.60
        case .ribbon: return 0.62
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                Color(hex: baseHex)
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .saturation(saturation)
                    .contrast(template == .editorial ? 1.02 : 0.96)
                    .brightness(0.01)
                    .colorMultiply(Color(hex: multiplyHex))
                Color(hex: 0xFFF8E8).opacity(template == .postcard ? 0.03 : 0.07)
                PaperGrainOverlay()
                PaperEdgeShading()
            }
            .clipShape(RoundedRectangle(cornerRadius: max(4, width * 0.009), style: .continuous))
            .shadow(color: Color(hex: 0x1E0F04).opacity(0.45), radius: width * 0.029, y: width * 0.011)
        }
    }
}

private struct PaperEdgeShading: View {
    var body: some View {
        Canvas { context, size in
            let edge = Color(hex: 0x5A3C19)
            let bands: [(CGRect, CGPoint, CGPoint, Double)] = [
                (CGRect(x: 0, y: 0, width: size.width, height: size.width * 0.044),
                 CGPoint(x: 0, y: 0), CGPoint(x: 0, y: size.width * 0.044), 0.12),
                (CGRect(x: 0, y: size.height - size.width * 0.051, width: size.width, height: size.width * 0.051),
                 CGPoint(x: 0, y: size.height), CGPoint(x: 0, y: size.height - size.width * 0.051), 0.14),
                (CGRect(x: 0, y: 0, width: size.width * 0.038, height: size.height),
                 CGPoint(x: 0, y: 0), CGPoint(x: size.width * 0.038, y: 0), 0.10),
                (CGRect(x: size.width - size.width * 0.038, y: 0, width: size.width * 0.038, height: size.height),
                 CGPoint(x: size.width, y: 0), CGPoint(x: size.width - size.width * 0.038, y: 0), 0.10)
            ]
            for (rect, start, end, opacity) in bands {
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [edge.opacity(opacity), .clear]),
                        startPoint: start,
                        endPoint: end
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PaperGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            var state: UInt64 = 0x0C0FFEE123456789
            func random() -> CGFloat {
                state = state &* 2862933555777941757 &+ 3037000493
                return CGFloat((state >> 33) & 0xFFFF) / CGFloat(0xFFFF)
            }
            let grainCount = Int(220 + min(1, size.width / 1_000) * 480)
            for _ in 0..<grainCount {
                let opacity = 0.015 + random() * 0.03
                let rect = CGRect(x: random() * size.width, y: random() * size.height, width: 1.2, height: 1.2)
                context.fill(Path(rect), with: .color(Color(hex: 0x503C1E).opacity(opacity)))
            }
            for index in 0..<12 {
                let center = CGPoint(x: random() * size.width, y: random() * size.height)
                let radius = (0.07 + random() * 0.18) * size.width
                let dark = index.isMultiple(of: 2)
                let color = dark ? Color(hex: 0x785F37).opacity(0.040) : Color(hex: 0xFFFAEB).opacity(0.045)
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [color, .clear]),
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CorkBoardBackground: View {
    let template: BoardTemplate

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            var state: UInt64 = 0x9E3779B97F4A7C15
            func random() -> CGFloat {
                state = state &* 2862933555777941757 &+ 3037000493
                return CGFloat((state >> 33) & 0xFFFF) / CGFloat(0xFFFF)
            }

            switch template {
            case .editorial:
                context.fill(Path(rect), with: .color(Color(hex: 0xD8D2C4)))
                let lineCount = Int(70 + min(1, size.width / 900) * 90)
                for index in 0..<lineCount {
                    let fraction = CGFloat(index) / CGFloat(max(1, lineCount - 1))
                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: 0, y: fraction * size.height))
                    horizontal.addLine(to: CGPoint(x: size.width, y: fraction * size.height + random() * 1.4))
                    context.stroke(horizontal, with: .color(Color(hex: 0x746D61).opacity(0.055)), lineWidth: 0.7)
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: fraction * size.width, y: 0))
                    vertical.addLine(to: CGPoint(x: fraction * size.width + random() * 1.2, y: size.height))
                    context.stroke(vertical, with: .color(Color.white.opacity(0.065)), lineWidth: 0.7)
                }

            case .postcard:
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xB9935E), Color(hex: 0x8B6238)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                let fiberCount = Int(360 + min(1, size.width / 900) * 520)
                for _ in 0..<fiberCount {
                    let x = random() * size.width
                    let y = random() * size.height
                    var fiber = Path()
                    fiber.move(to: CGPoint(x: x, y: y))
                    fiber.addLine(to: CGPoint(x: x + 2 + random() * 8, y: y + (random() - 0.5) * 2))
                    context.stroke(fiber, with: .color(Color(hex: 0xF1D7A7).opacity(0.05 + random() * 0.08)), lineWidth: 0.7)
                }

            case .ribbon, .scrapbook:
                let base: (UInt, UInt) = template == .scrapbook ? (0xB98A58, 0x936037) : (0xB08556, 0x89562D)
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: base.0), Color(hex: base.1)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                let grainCount = Int(620 + min(1, size.width / 900) * 1_080)
                for index in 0..<grainCount {
                    let x = random() * size.width
                    let y = random() * size.height
                    let scale = 0.6 + random() * 2.6
                    let w = scale * (0.7 + random())
                    let h = scale * (0.5 + random() * 0.7)
                    let dark = index.isMultiple(of: 3)
                    let opacity = dark ? 0.05 + random() * 0.10 : 0.04 + random() * 0.09
                    let color = dark ? Color(hex: 0x462812).opacity(opacity) : Color(hex: 0xEBC38C).opacity(opacity)
                    var fleck = Path(ellipseIn: CGRect(x: -w, y: -h, width: w * 2, height: h * 2))
                    fleck = fleck.applying(CGAffineTransform(translationX: x, y: y).rotated(by: random() * .pi))
                    context.fill(fleck, with: .color(color))
                }
                let stainCount = Int(24 + min(1, size.width / 900) * 36)
                for index in 0..<stainCount {
                    let x = random() * size.width
                    let y = random() * size.height
                    let scale = 4 + random() * 10
                    let opacity = 0.05 + random() * 0.05
                    let color = index.isMultiple(of: 2) ? Color(hex: 0x5F3A1A).opacity(opacity) : Color(hex: 0xD7AC72).opacity(opacity)
                    context.fill(Path(ellipseIn: CGRect(x: x - scale, y: y - scale * 0.7, width: scale * 2, height: scale * 1.4)), with: .color(color))
                }
            }

            context.fill(
                Path(rect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color(hex: 0x281204).opacity(template == .editorial ? 0.18 : 0.36), location: 1)
                    ]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: min(size.width, size.height) * 0.35,
                    endRadius: max(size.width, size.height) * 0.72
                )
            )
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
        .background(MRScreenBackground())
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
