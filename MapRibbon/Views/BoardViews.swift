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
    @State private var showingThreadColorPicker = false
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
            Button("실 색상 선택") { showingThreadColorPicker = true }
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
        .onChange(of: draft.threadColor) { _, _ in hasUnsavedChanges = true }
        .onChange(of: draft.places) { _, _ in hasUnsavedChanges = true }
    }

    private var editorToolBar: some View {
        HStack(alignment: .top, spacing: 0) {
            BoardEditorToolButton(title: "사진 추가", symbol: "photo.badge.plus") {
                showingPlaces = true
            }

            BoardEditorToolButton(title: "실 색상", symbol: "paintpalette.fill") {
                showingThreadColorPicker = true
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
                BoardArchivePayload(date: draft.date, title: draft.title, places: draft.places, template: draft.template, threadColor: draft.threadColor)
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
        guard count > 1 else { return [] }
        return (0..<(count - 1)).map { ($0, $0 + 1) }
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
            premiumBoard(in: proxy.size)
        }
        .background(MRColor.cork)
        .clipped()
    }

    private func premiumBoard(in size: CGSize) -> some View {
        let outer = CGRect(origin: .zero, size: size)
        let boardInset = max(8, size.width * 0.028)
        let mapRect = outer.insetBy(dx: boardInset, dy: boardInset)
        let places = model.visiblePlaces.sorted { $0.startDate < $1.startDate }
        let placements = BoardLayoutEngine.cardPlacements(for: places.count, aspectRatio: size.width / max(1, size.height))
        let anchors = BoardLayoutEngine.anchorPoints(placements: placements, in: mapRect)

        return ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.028, style: .continuous)
                .fill(Color(hex: model.template == .scrapbook ? 0xA87542 : 0x9B673D))
                .overlay { PremiumCorkTexture().clipShape(RoundedRectangle(cornerRadius: size.width * 0.028, style: .continuous)) }
                .overlay { RoundedRectangle(cornerRadius: size.width * 0.028).stroke(.black.opacity(0.16), lineWidth: max(1, size.width * 0.002)) }

            paperMap(in: mapRect)
            photoCards(places: places, placements: placements, in: mapRect)
            routeLayer(anchors: anchors, width: mapRect.width)
            pinLayer(anchors: anchors, width: mapRect.width)
            titleNote(in: mapRect)

            if watermark {
                Text("Made with MapRibbon")
                    .font(.system(size: mapRect.width * 0.018, weight: .semibold))
                    .foregroundStyle(MRColor.ink.opacity(0.42))
                    .position(x: mapRect.maxX - mapRect.width * 0.13, y: mapRect.maxY - mapRect.height * 0.022)
            }
        }
    }

    private func paperMap(in rect: CGRect) -> some View {
        ZStack {
            Image(uiImage: model.mapImage)
                .resizable()
                .scaledToFit()
                .background(Color(hex: 0xE9E2D4))
                .saturation(0.38)
                .contrast(0.92)
                .brightness(0.055)
                .frame(width: rect.width, height: rect.height)
                .clipped()
            Color(hex: 0xF2EBDD).opacity(0.38)
            PremiumPaperGrain().opacity(0.68)
        }
        .frame(width: rect.width, height: rect.height)
        .clipShape(RoundedRectangle(cornerRadius: rect.width * 0.012, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: rect.width * 0.012).stroke(Color.black.opacity(0.13), lineWidth: max(0.8, rect.width * 0.0015)) }
        .shadow(color: .black.opacity(0.18), radius: rect.width * 0.014, y: rect.width * 0.009)
        .position(x: rect.midX, y: rect.midY)
    }

    private func routeLayer(anchors: [CGPoint], width: CGFloat) -> some View {
        Canvas { context, _ in
            guard anchors.count > 1 else { return }
            let ropeWidth = max(2.5, width * 0.0054)
            let threadColor = Color(hex: model.threadColor.primaryHex)
            let threadHighlight = Color(hex: model.threadColor.highlightHex)
            for index in 0..<(anchors.count - 1) {
                let start = anchors[index]
                let end = anchors[index + 1]
                let dx = end.x - start.x
                let bend = min(width * 0.055, abs(dx) * 0.18)
                let control1 = CGPoint(x: start.x + dx * 0.34, y: start.y + (index.isMultiple(of: 2) ? bend : -bend))
                let control2 = CGPoint(x: start.x + dx * 0.68, y: end.y + (index.isMultiple(of: 2) ? -bend : bend))
                var path = Path()
                path.move(to: start)
                path.addCurve(to: end, control1: control1, control2: control2)
                context.stroke(path, with: .color(.black.opacity(0.24)), style: StrokeStyle(lineWidth: ropeWidth * 1.42, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(threadColor), style: StrokeStyle(lineWidth: ropeWidth, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(threadHighlight.opacity(0.62)), style: StrokeStyle(lineWidth: max(0.55, ropeWidth * 0.16), lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func photoCards(places: [BoardPlace], placements: [BoardCardPlacement], in rect: CGRect) -> some View {
        ZStack {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                if index < placements.count, let image = model.photoImages[place.representativeAssetIdentifier] {
                    let placement = placements[index]
                    PremiumBoardPhotoCard(place: place, image: image, width: rect.width * placement.widthFactor, variant: index)
                        .rotationEffect(.degrees(placement.rotation))
                        .position(x: rect.minX + rect.width * placement.center.x, y: rect.minY + rect.height * placement.center.y)
                }
            }
        }
    }

    private func pinLayer(anchors: [CGPoint], width: CGFloat) -> some View {
        let assets = ["RoutePinBlue", "RoutePinTeal", "RoutePinYellow", "RoutePinCream", "RoutePinRed", "RoutePinGreen"]
        let pinWidth = max(20, width * 0.047)
        return ZStack {
            ForEach(anchors.indices, id: \.self) { index in
                Image(assets[index % assets.count])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: pinWidth, height: pinWidth * 1.56)
                    .shadow(color: .black.opacity(0.28), radius: pinWidth * 0.10, y: pinWidth * 0.08)
                    .position(x: anchors[index].x, y: anchors[index].y - pinWidth * 0.47)
            }
        }
    }

    private func titleNote(in rect: CGRect) -> some View {
        let width = rect.width * 0.405
        return ZStack {
            VStack(alignment: .leading, spacing: rect.height * 0.004) {
                Text(model.date.mrBoardDate)
                    .font(.system(size: rect.width * 0.024, weight: .medium, design: .serif))
                    .foregroundStyle(MRColor.ink.opacity(0.66))
                Text(model.title)
                    .font(.system(size: rect.width * 0.054, weight: .bold, design: .serif))
                    .foregroundStyle(MRColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text("사진으로 다시 엮은 여름의 하루")
                    .font(.system(size: rect.width * 0.0215, weight: .medium, design: .serif))
                    .foregroundStyle(MRColor.ink.opacity(0.58))
            }
            .padding(.horizontal, rect.width * 0.026)
            .padding(.vertical, rect.width * 0.022)
            .frame(width: width, alignment: .leading)
            .background(Color(hex: 0xFBF7ED))
            .overlay(PremiumPaperGrain().opacity(0.55))
            .overlay { Rectangle().stroke(Color.black.opacity(0.055), lineWidth: 0.7) }
            .rotationEffect(.degrees(-1.0))
            .shadow(color: .black.opacity(0.19), radius: rect.width * 0.014, y: rect.width * 0.010)
            .position(x: rect.minX + rect.width * 0.245, y: rect.minY + rect.height * 0.095)

            Image("RoutePinCream")
                .resizable()
                .scaledToFit()
                .frame(width: rect.width * 0.046, height: rect.width * 0.074)
                .position(x: rect.minX + rect.width * 0.245, y: rect.minY + rect.height * 0.044)
        }
    }
}

struct BoardCardPlacement: Equatable {
    let center: CGPoint
    let widthFactor: CGFloat
    let rotation: Double
}

enum BoardLayoutEngine {
    static func cardPlacements(for count: Int, aspectRatio: CGFloat) -> [BoardCardPlacement] {
        let isStory = aspectRatio < 0.64
        let isFeed = aspectRatio >= 0.64 && aspectRatio < 0.77
        let posterFive = [
            BoardCardPlacement(center: CGPoint(x: 0.285, y: 0.315), widthFactor: 0.245, rotation: -2.2),
            BoardCardPlacement(center: CGPoint(x: 0.755, y: 0.425), widthFactor: 0.245, rotation: 2.6),
            BoardCardPlacement(center: CGPoint(x: 0.275, y: 0.585), widthFactor: 0.238, rotation: -2.0),
            BoardCardPlacement(center: CGPoint(x: 0.315, y: 0.825), widthFactor: 0.245, rotation: 1.5),
            BoardCardPlacement(center: CGPoint(x: 0.735, y: 0.755), widthFactor: 0.248, rotation: 3.0),
        ]
        let feedFive = [
            BoardCardPlacement(center: CGPoint(x: 0.28, y: 0.31), widthFactor: 0.255, rotation: -2.0),
            BoardCardPlacement(center: CGPoint(x: 0.75, y: 0.39), widthFactor: 0.25, rotation: 2.4),
            BoardCardPlacement(center: CGPoint(x: 0.28, y: 0.58), widthFactor: 0.245, rotation: -1.6),
            BoardCardPlacement(center: CGPoint(x: 0.32, y: 0.82), widthFactor: 0.25, rotation: 1.4),
            BoardCardPlacement(center: CGPoint(x: 0.73, y: 0.73), widthFactor: 0.25, rotation: 2.8),
        ]
        let storyFive = [
            BoardCardPlacement(center: CGPoint(x: 0.30, y: 0.27), widthFactor: 0.285, rotation: -2.0),
            BoardCardPlacement(center: CGPoint(x: 0.72, y: 0.40), widthFactor: 0.28, rotation: 2.3),
            BoardCardPlacement(center: CGPoint(x: 0.30, y: 0.55), widthFactor: 0.275, rotation: -1.5),
            BoardCardPlacement(center: CGPoint(x: 0.31, y: 0.76), widthFactor: 0.28, rotation: 1.2),
            BoardCardPlacement(center: CGPoint(x: 0.70, y: 0.84), widthFactor: 0.285, rotation: 2.5),
        ]
        let base = isStory ? storyFive : (isFeed ? feedFive : posterFive)
        if count <= 0 { return [] }
        if count == 1 { return [BoardCardPlacement(center: CGPoint(x: 0.52, y: 0.56), widthFactor: isStory ? 0.46 : 0.40, rotation: -1.2)] }
        if count == 2 { return [base[0], BoardCardPlacement(center: CGPoint(x: 0.70, y: 0.66), widthFactor: base[1].widthFactor * 1.08, rotation: 2.2)] }
        if count == 3 { return [base[0], base[1], BoardCardPlacement(center: CGPoint(x: 0.38, y: 0.74), widthFactor: base[2].widthFactor * 1.04, rotation: -1.5)] }
        if count == 4 { return [base[0], base[1], base[2], BoardCardPlacement(center: CGPoint(x: 0.70, y: 0.76), widthFactor: base[3].widthFactor, rotation: 2.0)] }
        var result = base
        let extras = [
            BoardCardPlacement(center: CGPoint(x: 0.52, y: 0.52), widthFactor: 0.20, rotation: -1.0),
            BoardCardPlacement(center: CGPoint(x: 0.54, y: 0.90), widthFactor: 0.20, rotation: 1.8),
            BoardCardPlacement(center: CGPoint(x: 0.82, y: 0.60), widthFactor: 0.19, rotation: -2.2),
        ]
        if count > result.count { result.append(contentsOf: extras.prefix(count - result.count)) }
        return Array(result.prefix(min(count, 8)))
    }

    static func anchorPoints(placements: [BoardCardPlacement], in rect: CGRect) -> [CGPoint] {
        placements.map { placement in
            let width = rect.width * placement.widthFactor
            let height = width * 1.22
            let inset = height * 0.42
            let angle = placement.rotation * Double.pi / 180
            let center = CGPoint(x: rect.minX + rect.width * placement.center.x, y: rect.minY + rect.height * placement.center.y)
            return CGPoint(x: center.x + CGFloat(sin(angle)) * inset, y: center.y - CGFloat(cos(angle)) * inset)
        }
    }
}

private struct PremiumBoardPhotoCard: View {
    let place: BoardPlace
    let image: UIImage
    let width: CGFloat
    let variant: Int

    var body: some View {
        let height = width * 1.22
        let direction: CGFloat = variant.isMultiple(of: 2) ? 1 : -1
        let rearAngle = [2.0, -2.4, 1.6, -1.8, 2.4][variant % 5]
        ZStack {
            Rectangle()
                .fill(Color(hex: 0xF2EEE5))
                .frame(width: width, height: height)
                .rotationEffect(.degrees(rearAngle))
                .offset(x: direction * width * 0.075, y: height * 0.052)
            Rectangle()
                .fill(Color(hex: 0xFAF8F2))
                .frame(width: width, height: height)
                .rotationEffect(.degrees(-rearAngle * 0.55))
                .offset(x: -direction * width * 0.035, y: height * 0.028)
            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.88, height: height * 0.70)
                    .clipped()
                VStack(alignment: .leading, spacing: max(1, width * 0.012)) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(place.title)
                            .font(.system(size: width * 0.071, weight: .bold))
                            .foregroundStyle(MRColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 2)
                        Text("\(place.photoCount)장")
                            .font(.system(size: width * 0.052, weight: .bold))
                            .foregroundStyle(MRColor.accent)
                    }
                    Text(place.subtitle ?? place.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: width * 0.046, weight: .medium))
                        .foregroundStyle(MRColor.ink.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                .padding(.horizontal, width * 0.055)
                .padding(.top, width * 0.038)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(hex: 0xFBF9F3))
            }
            .padding(width * 0.052)
            .frame(width: width, height: height)
            .background(Color(hex: 0xFEFDF9))
            .overlay { Rectangle().stroke(Color.black.opacity(0.055), lineWidth: max(0.5, width * 0.003)) }
        }
        .shadow(color: .black.opacity(0.24), radius: width * 0.075, y: width * 0.050)
    }
}

private struct PremiumCorkTexture: View {
    var body: some View {
        Canvas { context, size in
            let bounds = Path(CGRect(origin: .zero, size: size))
            context.fill(bounds, with: .linearGradient(Gradient(colors: [Color(hex: 0xB98250), Color(hex: 0x86512D)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            var state: UInt64 = 0x9E3779B97F4A7C15
            func random() -> CGFloat {
                state = state &* 2862933555777941757 &+ 3037000493
                return CGFloat((state >> 33) & 0xFFFF) / CGFloat(0xFFFF)
            }
            let colors = [Color(hex: 0x4F2F1C).opacity(0.30), Color(hex: 0xD7AC72).opacity(0.38), Color(hex: 0xE8C391).opacity(0.25), Color.black.opacity(0.12)]
            for index in 0..<820 {
                let x = random() * size.width
                let y = random() * size.height
                let w = max(0.8, random() * size.width * 0.009)
                let h = max(0.45, w * (0.18 + random() * 0.42))
                var fleck = Path(roundedRect: CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h), cornerRadius: h * 0.5)
                fleck = fleck.applying(CGAffineTransform(translationX: x, y: y).rotated(by: (random() - 0.5) * 1.2))
                context.fill(fleck, with: .color(colors[index % colors.count]))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PremiumPaperGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<170 {
                let x = CGFloat((index * 43) % 173) / 173 * size.width
                let y = CGFloat((index * 71) % 179) / 179 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.15, height: 1.15)), with: .color(.black.opacity(0.028)))
            }
            for index in 0..<24 {
                let y = size.height * CGFloat(index + 1) / 25
                context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.28)), with: .color(.white.opacity(0.11)), lineWidth: 0.28)
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
