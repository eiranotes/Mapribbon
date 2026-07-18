import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var showingAddPlace = false
    @State private var showingQuickAdd = false
    @State private var showingRename = false
    @State private var showingCloseConfirmation = false
    @State private var exportedImage: UIImage?
    @State private var showingActivity = false
    @State private var toastMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var baselineFingerprint = ""
    @AppStorage("freeExportConsumed") private var freeExportConsumed = false

    var body: some View {
        ScrollView {
            BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: MRColor.ink.opacity(0.11), radius: 15, y: 7)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
        .background(MRColor.background)
        .navigationTitle("보드 편집")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: attemptClose) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("닫기")
            }
            ToolbarItem(placement: .topBarTrailing) {
                editorMenu
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            editorToolbar
        }
        .sheet(isPresented: $showingPlaces) {
            PlaceManagerView(draft: draft)
        }
        .sheet(isPresented: $showingAddPlace) {
            AddPlaceSheet(draft: draft)
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddSheet(
                selectedPhotoItems: $selectedPhotoItems,
                onAddPlace: {
                    showingQuickAdd = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        showingAddPlace = true
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingRename) {
            RenameBoardSheet(title: $draft.title)
                .presentationDetents([.height(210)])
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(draft: draft) { image, action in
                exportedImage = image
                if !store.isUnlocked { freeExportConsumed = true }
                do {
                    try persist(image)
                    baselineFingerprint = draft.fingerprint
                } catch {
                    toastMessage = "보드를 저장하지 못했습니다. \(error.localizedDescription)"
                    return
                }

                showingExport = false
                switch action {
                case .share:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showingActivity = true
                    }
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
        .confirmationDialog(
            "저장하지 않은 변경사항이 있습니다.",
            isPresented: $showingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("계속 편집", role: .cancel) {}
            Button("변경사항 버리기", role: .destructive) { onClose() }
        }
        .alert("MapRibbon", isPresented: Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )) {
            Button("확인", role: .cancel) { toastMessage = nil }
        } message: {
            Text(toastMessage ?? "")
        }
        .overlay {
            if isImportingPhotos {
                ProgressView("사진 추가 중")
                    .padding(22)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .onAppear {
            if baselineFingerprint.isEmpty {
                baselineFingerprint = draft.fingerprint
            }
        }
        .onChange(of: selectedPhotoItems.count) { _, count in
            guard count > 0 else { return }
            Task { await importSelectedPhotos() }
        }
    }

    private var editorMenu: some View {
        Menu {
            Button {
                showingRename = true
            } label: {
                Label("제목 수정", systemImage: "pencil")
            }

            Menu("템플릿") {
                ForEach(BoardTemplate.allCases) { template in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            draft.template = template
                        }
                    } label: {
                        if draft.template == template {
                            Label(template.title, systemImage: "checkmark")
                        } else {
                            Text(template.title)
                        }
                    }
                }
            }

            Button {
                showingPlaces = true
            } label: {
                Label("장소와 사진 관리", systemImage: "slider.horizontal.3")
            }

            Button {
                openExport()
            } label: {
                Label("저장 및 공유", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel("더 보기")
    }

    private var editorToolbar: some View {
        HStack(alignment: .center, spacing: 6) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 20,
                matching: .images
            ) {
                EditorToolbarItem(title: "사진 추가", symbol: "photo.badge.plus")
            }
            .buttonStyle(.plain)

            Button {
                showingAddPlace = true
            } label: {
                EditorToolbarItem(title: "장소 추가", symbol: "mappin.and.ellipse")
            }
            .buttonStyle(.plain)

            Button {
                showingQuickAdd = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MRCircularAddButtonStyle())
            .accessibilityLabel("빠른 추가")

            Button {
                showingPlaces = true
            } label: {
                EditorToolbarItem(title: "순서 변경", symbol: "arrow.up.arrow.down")
            }
            .buttonStyle(.plain)

            Button {
                openExport()
            } label: {
                EditorToolbarItem(title: "저장 및 공유", symbol: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(MRColor.border).frame(height: 0.5)
        }
    }

    private func openExport() {
        if !store.isUnlocked && freeExportConsumed {
            showingPaywall = true
        } else {
            showingExport = true
        }
    }

    private func attemptClose() {
        if draft.fingerprint == baselineFingerprint {
            onClose()
        } else {
            showingCloseConfirmation = true
        }
    }

    @MainActor
    private func importSelectedPhotos() async {
        let items = selectedPhotoItems
        selectedPhotoItems = []
        guard !items.isEmpty else { return }
        isImportingPhotos = true
        defer { isImportingPhotos = false }

        var photos: [ImportedBoardPhoto] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                continue
            }
            photos.append(
                ImportedBoardPhoto(
                    identifier: "import-\(UUID().uuidString)",
                    image: image
                )
            )
        }

        guard !photos.isEmpty else {
            toastMessage = "선택한 사진을 불러오지 못했습니다."
            return
        }
        draft.appendImportedPhotos(photos)
        toastMessage = "사진 \(photos.count)장을 새 장소에 추가했습니다."
    }

    private func persist(_ image: UIImage) throws {
        guard let previewData = image.jpegData(compressionQuality: 0.86) else {
            throw BoardPersistenceError.imageEncodingFailed
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadData = try encoder.encode(draft.archivePayload)

        let regions = Array(Set(draft.places.compactMap { RegionNormalizer.key(from: $0.administrativeArea) })).sorted()
        let regionData = try encoder.encode(regions)
        let regionJSON = String(data: regionData, encoding: .utf8) ?? "[]"

        let identifier = draft.id
        let descriptor = FetchDescriptor<SavedBoard>(predicate: #Predicate { $0.id == identifier })
        if let existing = try modelContext.fetch(descriptor).first {
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
        try modelContext.save()
    }
}

private enum BoardPersistenceError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "내보내기 이미지를 인코딩할 수 없습니다."
        }
    }
}

private struct EditorToolbarItem: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(height: 22)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(MRColor.primaryText)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private struct QuickAddSheet: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let onAddPlace: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("사진 추가", systemImage: "photo.badge.plus")
                }
                .buttonStyle(MRPrimaryButtonStyle())

                Button {
                    onAddPlace()
                } label: {
                    Label("장소 추가", systemImage: "mappin.and.ellipse")
                }
                .buttonStyle(MRSecondaryButtonStyle())

                Spacer()
            }
            .padding(20)
            .background(MRColor.background)
            .navigationTitle("빠른 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

private struct RenameBoardSheet: View {
    @Binding var title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("보드 제목", text: $title)
            }
            .navigationTitle("제목 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

enum ExportAction { case share, save }

struct ExportSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(StoreService.self) private var store
    let onExport: (UIImage, ExportAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultExportFormat") private var defaultFormatRaw = ExportFormat.story.rawValue
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: MRColor.ink.opacity(0.08), radius: 12, y: 6)
                    .frame(maxHeight: 480)

                HStack(spacing: 12) {
                    Button {
                        Task { if let image = await render() { onExport(image, .save) } }
                    } label: { Label("저장", systemImage: "square.and.arrow.down") }
                    .buttonStyle(MRSecondaryButtonStyle())
                    .disabled(isRendering)

                    Button {
                        Task { if let image = await render() { onExport(image, .share) } }
                    } label: { Label("공유", systemImage: "square.and.arrow.up") }
                    .buttonStyle(MRPrimaryButtonStyle())
                    .disabled(isRendering)
                }
            }
            .padding(20)
            .background(MRColor.background)
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
            .overlay {
                if isRendering {
                    ProgressView()
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .onAppear {
                format = ExportFormat.resolved(from: defaultFormatRaw)
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
    @State private var showingAddPlace = false
    @State private var showingMerge = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($draft.places) { $place in
                    NavigationLink {
                        PlaceEditorView(place: $place, draft: draft)
                    } label: {
                        HStack(spacing: 12) {
                            BoardPhotoThumbnail(
                                identifier: place.representativeAssetIdentifier,
                                images: draft.photoImages,
                                size: CGSize(width: 56, height: 56)
                            )
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(place.isHidden ? 0.35 : 1)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text("사진 \(place.photoCount)장 · \(place.startDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(MRColor.secondaryText)
                            }
                        }
                    }
                }
                .onMove { source, destination in
                    draft.reorderPlaces(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    let ids = offsets.map { draft.places[$0].id }
                    ids.forEach(draft.deletePlace)
                }
            }
            .navigationTitle("장소와 사진")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddPlace = true
                        } label: {
                            Label("장소 추가", systemImage: "plus")
                        }
                        Button {
                            showingMerge = true
                        } label: {
                            Label("장소 병합", systemImage: "arrow.triangle.merge")
                        }
                        .disabled(draft.places.count < 2)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    Button("완료") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAddPlace) {
            AddPlaceSheet(draft: draft)
        }
        .sheet(isPresented: $showingMerge) {
            MergePlacesSheet(draft: draft)
                .presentationDetents([.medium])
        }
    }
}

private struct AddPlaceSheet: View {
    let draft: BoardDraft
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var subtitle = ""
    @State private var startDate: Date
    @State private var endDate: Date

    init(draft: BoardDraft) {
        self.draft = draft
        _startDate = State(initialValue: draft.date)
        _endDate = State(initialValue: draft.date.addingTimeInterval(3_600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("장소") {
                    TextField("장소 이름", text: $title)
                    TextField("설명", text: $subtitle)
                }
                Section("시간") {
                    DatePicker("시작", selection: $startDate)
                    DatePicker("종료", selection: $endDate)
                }
            }
            .navigationTitle("장소 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("추가") {
                        draft.appendManualPlace(
                            title: title,
                            subtitle: subtitle,
                            startDate: startDate,
                            endDate: endDate
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct MergePlacesSheet: View {
    let draft: BoardDraft
    @Environment(\.dismiss) private var dismiss
    @State private var sourceID: UUID?
    @State private var targetID: UUID?

    init(draft: BoardDraft) {
        self.draft = draft
        _sourceID = State(initialValue: draft.places.first?.id)
        _targetID = State(initialValue: draft.places.dropFirst().first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("합칠 장소", selection: $sourceID) {
                    ForEach(draft.places) { place in
                        Text(place.title).tag(Optional(place.id))
                    }
                }
                Picker("남길 장소", selection: $targetID) {
                    ForEach(draft.places) { place in
                        Text(place.title).tag(Optional(place.id))
                    }
                }
                Text("사진과 시간 범위를 합치고, 남길 장소의 이름과 위치를 유지합니다.")
                    .font(.footnote)
                    .foregroundStyle(MRColor.secondaryText)
            }
            .navigationTitle("장소 병합")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("병합") {
                        guard let sourceID, let targetID,
                              draft.mergePlace(sourceID: sourceID, into: targetID) else { return }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(sourceID == nil || targetID == nil || sourceID == targetID)
                }
            }
        }
    }
}

struct PlaceEditorView: View {
    @Binding var place: BoardPlace
    @Bindable var draft: BoardDraft
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var confirmingDelete = false
    @State private var isImporting = false

    var body: some View {
        Form {
            Section("장소") {
                TextField("장소 이름", text: $place.title)
                TextField("설명", text: Binding($place.subtitle, replacingNilWith: ""))
                Toggle("보드에 표시", isOn: Binding(get: { !place.isHidden }, set: { place.isHidden = !$0 }))
            }

            Section("시간") {
                DatePicker("시작", selection: $place.startDate)
                DatePicker("종료", selection: $place.endDate, in: place.startDate...)
            }

            Section("사진") {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("이 장소에 사진 추가", systemImage: "photo.badge.plus")
                }

                if place.assetIdentifiers.isEmpty {
                    Text("아직 연결된 사진이 없습니다.")
                        .foregroundStyle(MRColor.secondaryText)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(place.assetIdentifiers, id: \.self) { identifier in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    place.representativeAssetIdentifier = identifier
                                } label: {
                                    BoardPhotoThumbnail(
                                        identifier: identifier,
                                        images: draft.photoImages,
                                        size: CGSize(width: 180, height: 180)
                                    )
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .bottomTrailing) {
                                        if place.representativeAssetIdentifier == identifier {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 23))
                                                .foregroundStyle(MRColor.accent)
                                                .background(Circle().fill(MRColor.paper))
                                                .padding(6)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    draft.removePhoto(identifier: identifier, from: place.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(MRColor.paper, MRColor.ink.opacity(0.72))
                                }
                                .padding(5)
                                .accessibilityLabel("사진 제거")
                            }
                        }
                    }
                }
            }

            Section {
                Button("장소 삭제", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle(place.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isImporting {
                ProgressView("사진 추가 중")
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .onChange(of: selectedPhotoItems.count) { _, count in
            guard count > 0 else { return }
            Task { await importSelectedPhotos() }
        }
        .confirmationDialog("이 장소를 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                let id = place.id
                draft.deletePlace(id: id)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }

    @MainActor
    private func importSelectedPhotos() async {
        let items = selectedPhotoItems
        selectedPhotoItems = []
        isImporting = true
        defer { isImporting = false }

        var photos: [ImportedBoardPhoto] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            photos.append(
                ImportedBoardPhoto(
                    identifier: "import-\(UUID().uuidString)",
                    image: image
                )
            )
        }
        draft.appendImportedPhotos(photos, to: place.id)
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
            signatureBoard(in: proxy.size)
        }
        .background(MRColor.background)
        .clipped()
    }

    private func signatureBoard(in size: CGSize) -> some View {
        let aspectRatio = size.width / max(size.height, 1)
        let centers = BoardLayout.cardCenters(count: model.visiblePlaces.count, aspectRatio: aspectRatio)
        let cardWidth = size.width * (BoardLayout.isTall(aspectRatio: aspectRatio) ? 0.255 : 0.205)

        return ZStack {
            CorkTextureView()

            RoundedRectangle(cornerRadius: max(8, size.width * 0.025), style: .continuous)
                .fill(MRColor.paper)
                .overlay {
                    Image(uiImage: model.mapImage)
                        .resizable()
                        .scaledToFill()
                        .opacity(mapOpacity)
                        .clipShape(RoundedRectangle(cornerRadius: max(7, size.width * 0.023), style: .continuous))
                }
                .overlay {
                    PaperGrainView()
                        .clipShape(RoundedRectangle(cornerRadius: max(7, size.width * 0.023), style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: max(8, size.width * 0.025), style: .continuous)
                        .stroke(MRColor.ink.opacity(0.16), lineWidth: max(1, size.width * 0.0025))
                }
                .padding(size.width * 0.032)
                .shadow(color: MRColor.ink.opacity(0.18), radius: size.width * 0.018, y: size.width * 0.012)

            ThreadLayer(
                segments: BoardLayout.threadSegments(count: model.visiblePlaces.count, aspectRatio: aspectRatio)
            )

            ForEach(Array(model.visiblePlaces.enumerated()), id: \.element.id) { index, place in
                if index < centers.count {
                    PlacePhotoStackCard(
                        place: place,
                        images: model.photoImages,
                        width: cardWidth,
                        template: model.template
                    )
                    .position(
                        x: centers[index].x * size.width,
                        y: centers[index].y * size.height
                    )
                }
            }

            BoardTitlePaper(model: model, size: size)
                .position(x: size.width * 0.30, y: size.height * 0.115)

            footer(size)
        }
    }

    private var mapOpacity: Double {
        switch model.template {
        case .ribbon: return 0.77
        case .editorial: return 0.60
        case .postcard: return 0.70
        case .scrapbook: return 0.52
        }
    }

    private func footer(_ size: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                Text("사진 \(model.photoCount)장 · 장소 \(model.visiblePlaces.count)곳")
                Spacer()
                if watermark { Text("Made with MapRibbon") }
            }
            .font(.system(size: max(8, size.width * 0.026), weight: .semibold))
            .foregroundStyle(MRColor.ink.opacity(0.60))
            .padding(.horizontal, size.width * 0.07)
            .padding(.bottom, size.height * 0.035)
        }
    }
}

private struct CorkTextureView: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MRColor.background))
            let spacing = max(7, size.width / 55)
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? spacing * 0.45 : 0
                while x < size.width {
                    let radius = CGFloat((Int(x + y) % 3) + 1) * 0.42
                    let rect = CGRect(x: x, y: y, width: radius, height: radius * 0.72)
                    context.fill(Path(ellipseIn: rect), with: .color(MRColor.cork))
                    x += spacing
                }
                row += 1
                y += spacing * 0.72
            }
        }
    }
}

private struct PaperGrainView: View {
    var body: some View {
        Canvas { context, size in
            let spacing = max(8, size.width / 48)
            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing * 0.65
                while x < size.width {
                    let width = CGFloat((Int(x + y) % 4) + 1) * 0.34
                    let rect = CGRect(x: x, y: y, width: width, height: 0.55)
                    context.fill(Path(rect), with: .color(MRColor.ink.opacity(0.055)))
                    x += spacing
                }
                y += spacing * 0.78
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

private struct ThreadLayer: View {
    let segments: [BoardThreadSegment]

    var body: some View {
        Canvas { context, canvas in
            for segment in segments {
                var path = Path()
                path.move(to: CGPoint(x: segment.start.x * canvas.width, y: segment.start.y * canvas.height))
                path.addLine(to: CGPoint(x: segment.end.x * canvas.width, y: segment.end.y * canvas.height))

                context.stroke(
                    path,
                    with: .color(MRColor.threadShadow),
                    style: StrokeStyle(lineWidth: max(3, canvas.width * 0.010), lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(MRColor.accent),
                    style: StrokeStyle(lineWidth: max(2, canvas.width * 0.007), lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(MRColor.paper.opacity(0.32)),
                    style: StrokeStyle(
                        lineWidth: max(0.7, canvas.width * 0.0018),
                        lineCap: .round,
                        dash: [max(2, canvas.width * 0.006), max(2, canvas.width * 0.005)]
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BoardTitlePaper: View {
    let model: BoardRenderModel
    let size: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: size.height * 0.004) {
            Text(model.date.mrBoardDate)
                .font(.system(size: max(8, size.width * 0.026), weight: .medium))
                .foregroundStyle(MRColor.secondaryText)
            Text(model.title)
                .font(.system(size: max(13, size.width * 0.055), weight: .bold, design: model.template == .postcard ? .serif : .default))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text("사진으로 다시 엮은 하루")
                .font(.system(size: max(7, size.width * 0.023), weight: .medium))
                .foregroundStyle(MRColor.secondaryText)
        }
        .foregroundStyle(MRColor.ink)
        .padding(.horizontal, size.width * 0.035)
        .padding(.vertical, size.height * 0.014)
        .frame(width: size.width * 0.50, alignment: .leading)
        .background(MRColor.paper.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.009, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size.width * 0.009, style: .continuous)
                .stroke(MRColor.border, lineWidth: 0.8)
        }
        .shadow(color: MRColor.ink.opacity(0.16), radius: size.width * 0.012, y: size.width * 0.008)
        .overlay(alignment: .top) {
            PushPinView(size: max(9, size.width * 0.023))
                .offset(y: -size.width * 0.012)
        }
    }
}

private struct PlacePhotoStackCard: View {
    let place: BoardPlace
    let images: [String: UIImage]
    let width: CGFloat
    let template: BoardTemplate

    private var identifiers: [String] {
        let values = Array(place.assetIdentifiers.prefix(3))
        return values.isEmpty ? [""] : values
    }

    var body: some View {
        ZStack {
            ForEach(Array(identifiers.enumerated().reversed()), id: \.offset) { index, identifier in
                PolaroidCardFace(
                    place: place,
                    image: images[identifier],
                    width: width,
                    isTop: index == 0
                )
                .offset(x: CGFloat(index) * width * 0.045, y: CGFloat(index) * width * 0.035)
                .rotationEffect(.degrees(rotation(for: index)))
            }
        }
        .overlay(alignment: .top) {
            PushPinView(size: max(10, width * 0.11))
                .offset(y: -width * 0.065)
        }
    }

    private func rotation(for index: Int) -> Double {
        switch index {
        case 0: return template == .scrapbook ? -1.2 : 0.4
        case 1: return 1.7
        default: return -1.8
        }
    }
}

private struct PolaroidCardFace: View {
    let place: BoardPlace
    let image: UIImage?
    let width: CGFloat
    let isTop: Bool

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    MRPhotoPlaceholder()
                }
            }
            .frame(width: width * 0.84, height: width * 0.66)
            .clipped()

            if isTop {
                VStack(alignment: .leading, spacing: max(1, width * 0.018)) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(place.title)
                            .font(.system(size: max(7, width * 0.092), weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 2)
                        Text("\(place.photoCount)장")
                            .font(.system(size: max(6, width * 0.070), weight: .bold))
                            .foregroundStyle(MRColor.accent)
                    }
                    Text(timeRange)
                        .font(.system(size: max(5.5, width * 0.061), weight: .medium))
                        .foregroundStyle(MRColor.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                .padding(.horizontal, width * 0.08)
                .padding(.top, width * 0.055)
                .padding(.bottom, width * 0.065)
            } else {
                Color.clear.frame(height: width * 0.27)
            }
        }
        .padding(.top, width * 0.075)
        .background(MRColor.paper)
        .frame(width: width, height: width * 1.15)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.018, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: width * 0.018, style: .continuous)
                .stroke(MRColor.ink.opacity(0.12), lineWidth: max(0.5, width * 0.006))
        }
        .shadow(color: MRColor.ink.opacity(0.20), radius: width * 0.055, y: width * 0.035)
    }

    private var timeRange: String {
        let start = place.startDate.formatted(date: .omitted, time: .shortened)
        let end = place.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
    }
}

private struct PushPinView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(MRColor.ink.opacity(0.24))
                .frame(width: size * 0.22, height: size * 0.62)
                .offset(y: size * 0.29)
                .rotationEffect(.degrees(7))

            Circle()
                .fill(MRColor.accent)
                .frame(width: size, height: size)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(MRColor.paper.opacity(0.48))
                        .frame(width: size * 0.32, height: size * 0.32)
                        .offset(x: size * 0.18, y: size * 0.14)
                }
                .overlay {
                    Circle().stroke(MRColor.ink.opacity(0.18), lineWidth: max(0.5, size * 0.045))
                }
                .shadow(color: MRColor.ink.opacity(0.25), radius: size * 0.20, y: size * 0.18)
        }
        .frame(width: size, height: size * 1.25)
    }
}

private struct BoardPhotoThumbnail: View {
    let identifier: String
    let images: [String: UIImage]
    let size: CGSize
    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = images[identifier] ?? loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                MRPhotoPlaceholder()
            }
        }
        .task(id: identifier) {
            guard !identifier.isEmpty, images[identifier] == nil else { return }
            loadedImage = await PhotoImageService.shared.image(for: identifier, targetSize: size)
        }
    }
}

struct SavedBoardDetailView: View {
    let board: SavedBoard
    @State private var showingActivity = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
#if DEBUG
                if ScreenshotLaunch.isEnabled {
                    BoardCanvasView(model: ScreenshotFixtures.makeDraft().renderModel, watermark: false)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: MRColor.ink.opacity(0.10), radius: 15, y: 7)
                    Button { showingActivity = true } label: { Label("공유", systemImage: "square.and.arrow.up") }
                        .buttonStyle(MRPrimaryButtonStyle())
                } else if let image = UIImage(data: board.previewImageData) {
                    savedImage(image)
                }
#else
                if let image = UIImage(data: board.previewImageData) {
                    savedImage(image)
                }
#endif
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

    private func savedImage(_ image: UIImage) -> some View {
        VStack(spacing: 18) {
            Image(uiImage: image).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: MRColor.ink.opacity(0.10), radius: 15, y: 7)
            Button { showingActivity = true } label: { Label("공유", systemImage: "square.and.arrow.up") }
                .buttonStyle(MRPrimaryButtonStyle())
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
