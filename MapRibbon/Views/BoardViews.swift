import SwiftUI
import SwiftData

struct GenerationFlowView: View {
    let summary: PhotoDaySummary
    @Environment(\.dismiss) private var dismiss

    @State private var selectionMode: PhotoSelectionMode = .automatic
    @State private var selectedIdentifiers: Set<String> = []
    @State private var hasStarted = false
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
                } else if hasStarted {
                    GenerationProgressView(step: step, progress: progress)
                } else {
                    PhotoSelectionStageView(
                        summary: summary,
                        mode: $selectionMode,
                        selectedIdentifiers: $selectedIdentifiers,
                        onCancel: { dismiss() },
                        onContinue: startGeneration
                    )
                }
            }
            .background(MRColor.background.ignoresSafeArea())
        }
        .interactiveDismissDisabled(hasStarted && draft == nil && errorMessage == nil)
        .onAppear {
            if selectedIdentifiers.isEmpty { selectedIdentifiers = automaticIdentifiers }
        }
        .onChange(of: selectionMode) { _, mode in
            if mode == .automatic { selectedIdentifiers = automaticIdentifiers }
        }
    }

    private var automaticIdentifiers: Set<String> {
        let clusters = PhotoClusterer.cluster(summary.assets)
        var ids: [String] = []
        for cluster in clusters {
            let sorted = cluster.assets
                .filter { !$0.isScreenshot }
                .sorted {
                    if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                    return $0.creationDate < $1.creationDate
                }
            ids.append(contentsOf: sorted.prefix(8).map(\.id))
        }
        return Set(ids.prefix(48))
    }

    private func startGeneration() {
        guard selectedIdentifiers.count >= 2 else { return }
        hasStarted = true
        let filtered = summary.filtering(to: selectedIdentifiers)
        Task {
            let generator = BoardGenerationService()
            do {
                draft = try await generator.generate(from: filtered) { newStep, newProgress in
                    step = newStep
                    progress = newProgress
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct PhotoSelectionStageView: View {
    let summary: PhotoDaySummary
    @Binding var mode: PhotoSelectionMode
    @Binding var selectedIdentifiers: Set<String>
    let onCancel: () -> Void
    let onContinue: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Button("닫기", action: onCancel)
                            .foregroundStyle(MRColor.secondaryText)
                        Spacer()
                        Text("사진 선택")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Color.clear.frame(width: 30)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.date.mrDayTitle)
                            .font(.system(size: 26, weight: .bold))
                        Text("위치가 포함된 사진을 골라 장소별 핀보드를 만듭니다.")
                            .font(.system(size: 14))
                            .foregroundStyle(MRColor.secondaryText)
                    }

                    Picker("선택 방식", selection: $mode) {
                        ForEach(PhotoSelectionMode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(mode == .automatic ? "장소별 대표 장면을 자동으로 골랐습니다." : "보드에 사용할 사진을 직접 고르세요.")
                            .font(.system(size: 13))
                            .foregroundStyle(MRColor.secondaryText)
                        Spacer()
                        Text("\(selectedIdentifiers.count)장")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MRColor.accent)
                    }

                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(summary.assets) { asset in
                            Button {
                                guard mode == .manual else { return }
                                if selectedIdentifiers.contains(asset.id) {
                                    selectedIdentifiers.remove(asset.id)
                                } else {
                                    selectedIdentifiers.insert(asset.id)
                                }
                            } label: {
                                AssetThumbnailView(identifier: asset.id, size: CGSize(width: 220, height: 220))
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .overlay(alignment: .topTrailing) {
                                        if selectedIdentifiers.contains(asset.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 21))
                                                .foregroundStyle(MRColor.accent)
                                                .background(Circle().fill(.white))
                                                .padding(5)
                                        }
                                    }
                                    .overlay {
                                        if !selectedIdentifiers.contains(asset.id) {
                                            Color.black.opacity(mode == .manual ? 0.26 : 0.16)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(mode == .automatic)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(MRSpacing.screen)
                .padding(.bottom, 90)
            }

            MRBottomActionBar {
                Button {
                    onContinue()
                } label: {
                    Label("자동 보드 만들기", systemImage: "wand.and.stars")
                }
                .buttonStyle(MRPrimaryButtonStyle())
                .disabled(selectedIdentifiers.count < 2)
                .opacity(selectedIdentifiers.count < 2 ? 0.45 : 1)
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
                Text("핀보드 생성 중")
                    .font(.system(size: 24, weight: .bold))
                Text(step.title)
                    .font(.system(size: 15))
                    .foregroundStyle(MRColor.secondaryText)
            }
            VStack(alignment: .leading, spacing: 13) {
                ForEach(GenerationStep.allCases) { item in
                    HStack(spacing: 10) {
                        Image(systemName: stateSymbol(for: item)).foregroundStyle(stateColor(for: item))
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
    @State private var showingTextEditor = false
    @State private var showingExport = false
    @State private var showingPaywall = false
    @State private var exportedImage: UIImage?
    @State private var showingActivity = false
    @State private var toastMessage: String?
    @AppStorage("freeExportConsumed") private var freeExportConsumed = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    InteractiveBoardPreview(draft: draft)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.10), radius: 15, y: 7)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        templatePicker

                        HStack(spacing: 10) {
                            Button { showingPlaces = true } label: {
                                Label("사진·순서", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            }
                            .buttonStyle(MRSecondaryButtonStyle())

                            Button { showingTextEditor = true } label: {
                                Label("문구", systemImage: "textformat")
                            }
                            .buttonStyle(MRSecondaryButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
                .padding(.top, 12)
            }

            MRBottomActionBar {
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
        }
        .background(MRColor.background)
        .navigationTitle("미리보기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("닫기") { onClose() } }
        }
        .sheet(isPresented: $showingPlaces) { PlaceManagerView(draft: draft) }
        .sheet(isPresented: $showingTextEditor) { BoardTextEditor(draft: draft) }
        .sheet(isPresented: $showingExport) {
            ExportSheet(draft: draft) { image, action in
                exportedImage = image
                if !store.isUnlocked { freeExportConsumed = true }
                persist(image)
                switch action {
                case .share:
                    showingExport = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { showingActivity = true }
                case .save:
                    Task {
                        do {
                            try await PhotoSaveService.save(image)
                            toastMessage = "사진 보관함에 저장했습니다."
                        } catch { toastMessage = error.localizedDescription }
                    }
                case .instagram:
                    Task {
                        let opened = await InstagramShareService.shareStory(image: image)
                        if !opened { toastMessage = "Instagram 앱을 열 수 없습니다." }
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
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("보드 스타일").font(.system(size: 16, weight: .bold))
            HStack(spacing: 8) {
                ForEach(BoardTemplate.allCases) { template in
                    Button {
                        withAnimation(MRMotion.standard) { draft.template = template }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: template.symbolName).font(.system(size: 17, weight: .semibold))
                            Text(template.title).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(draft.template == template ? MRColor.accent : MRColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(draft.template == template ? MRColor.accentSoft : MRColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(draft.template == template ? MRColor.accent : MRColor.border) }
                    }
                    .buttonStyle(MRPressableCardStyle())
                }
            }
        }
    }

    private func persist(_ image: UIImage) {
        guard let previewData = image.jpegData(compressionQuality: 0.86),
              let payloadData = try? JSONEncoder().encode(
                BoardArchivePayload(date: draft.date, title: draft.title, caption: draft.caption, places: draft.places, template: draft.template)
              ) else { return }

        let regions = Array(Set(draft.places.compactMap { RegionNormalizer.key(from: $0.administrativeArea) })).sorted()
        let regionJSON = String(data: (try? JSONEncoder().encode(regions)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        let identifier = draft.id
        let descriptor = FetchDescriptor<SavedBoard>(predicate: #Predicate { $0.id == identifier })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.date = draft.date
            existing.createdAt = .now
            existing.title = draft.title
            existing.photoCount = draft.renderModel.photoCount
            existing.placeCount = draft.renderModel.visiblePlaces.count
            existing.templateRawValue = draft.template.rawValue
            existing.previewImageData = previewData
            existing.payloadData = payloadData
            existing.regionKeysJSON = regionJSON
        } else {
            modelContext.insert(SavedBoard(
                id: draft.id,
                date: draft.date,
                title: draft.title,
                photoCount: draft.renderModel.photoCount,
                placeCount: draft.renderModel.visiblePlaces.count,
                templateRawValue: draft.template.rawValue,
                previewImageData: previewData,
                payloadData: payloadData,
                regionKeysJSON: regionJSON
            ))
        }
        try? modelContext.save()
    }
}

private struct BoardTextEditor: View {
    @Bindable var draft: BoardDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") { TextField("예: 부산 하루 여행", text: $draft.title) }
                Section("한 줄 문구") {
                    TextField("예: 바다를 따라 천천히", text: $draft.caption, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("비워두면 보드에는 표시하지 않습니다.")
                }
            }
            .navigationTitle("문구 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
        }
    }
}

enum ExportAction { case share, save, instagram }

struct ExportSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(StoreService.self) private var store
    let onExport: (UIImage, ExportAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .story
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("출력 비율", selection: $format) {
                        ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                        .aspectRatio(format.aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                        .frame(maxHeight: 500)

                    VStack(spacing: 10) {
                        Button {
                            Task { if let image = await render() { onExport(image, .instagram) } }
                        } label: {
                            Label("Instagram 스토리로 공유", systemImage: "camera")
                        }
                        .buttonStyle(MRPrimaryButtonStyle())
                        .disabled(isRendering)

                        HStack(spacing: 10) {
                            ExportActionButton(title: "사진에 저장", symbol: "square.and.arrow.down") {
                                Task { if let image = await render() { onExport(image, .save) } }
                            }
                            ExportActionButton(title: "다른 앱", symbol: "square.and.arrow.up") {
                                Task { if let image = await render() { onExport(image, .share) } }
                            }
                        }
                        .disabled(isRendering)

                        Text("공유되는 것은 완성된 보드 이미지뿐이며 원본 사진은 전송되지 않습니다.")
                            .font(.system(size: 12))
                            .foregroundStyle(MRColor.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(MRColor.background)
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
            .overlay {
                if isRendering {
                    ProgressView().padding(24).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
                }
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

private struct ExportActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(MRColor.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(MRColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(MRColor.border) }
        }
        .buttonStyle(MRPressableCardStyle())
    }
}

private struct DraftPhotoView: View {
    let identifier: String
    let images: [String: UIImage]
    let size: CGSize

    var body: some View {
        Group {
            if let image = images[identifier] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AssetThumbnailView(identifier: identifier, size: size)
            }
        }
    }
}

struct PlaceManagerView: View {
    @Bindable var draft: BoardDraft
    @Environment(\.dismiss) private var dismiss
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(draft.places.enumerated()), id: \.element.id) { index, place in
                        NavigationLink {
                            PlaceEditorView(placeID: place.id, draft: draft)
                        } label: {
                            HStack(spacing: 12) {
                                DraftPhotoView(identifier: place.representativeAssetIdentifier, images: draft.photoImages, size: CGSize(width: 58, height: 58))
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .opacity(place.isHidden ? 0.35 : 1)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("\(index + 1). \(place.title)")
                                            .font(.system(size: 15, weight: .semibold))
                                        if draft.isRepeatedLocation(at: index) {
                                            Text("재방문")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(MRColor.accent)
                                                .padding(.horizontal, 6).padding(.vertical, 3)
                                                .background(MRColor.accentSoft).clipShape(Capsule())
                                        }
                                    }
                                    Text("\(place.timeRangeText) · 사진 \(place.photoCount)장")
                                        .font(.system(size: 12)).foregroundStyle(MRColor.secondaryText)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("분리") {
                                toastMessage = draft.splitPlace(place.id) ? "가장 긴 시간 공백을 기준으로 분리했습니다." : "분리할 시간 공백이 없습니다."
                            }
                            .tint(MRColor.accent)
                            if index > 0 {
                                Button("이전과 합치기") { _ = draft.mergeWithPrevious(place.id) }
                                    .tint(MRColor.secondaryText)
                            }
                        }
                    }
                    .onMove { source, destination in
                        withAnimation(MRMotion.spatial) { draft.places.move(fromOffsets: source, toOffset: destination) }
                    }
                } header: {
                    Text("방문 순서")
                } footer: {
                    Text("같은 위치를 나중에 다시 방문한 경우 별도 정류장으로 유지합니다. 드래그해 연결 순서를 바꾸거나, 스와이프해 분리·합치기 할 수 있습니다.")
                }
            }
            .navigationTitle("사진과 순서")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } }
            }
            .alert("MapRibbon", isPresented: Binding(get: { toastMessage != nil }, set: { if !$0 { toastMessage = nil } })) {
                Button("확인", role: .cancel) {}
            } message: { Text(toastMessage ?? "") }
        }
    }
}

struct PlaceEditorView: View {
    let placeID: UUID
    @Bindable var draft: BoardDraft

    private var placeIndex: Int? { draft.places.firstIndex { $0.id == placeID } }

    var body: some View {
        Form {
            if let index = placeIndex {
                Section("장소") {
                    TextField("장소 이름", text: $draft.places[index].title)
                    TextField("설명", text: Binding($draft.places[index].subtitle, replacingNilWith: ""))
                    Toggle("보드에 표시", isOn: Binding(
                        get: { !draft.places[index].isHidden },
                        set: { draft.places[index].isHidden = !$0 }
                    ))
                }

                Section("당일 사진") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(draft.allSourceIdentifiers, id: \.self) { identifier in
                            let selected = draft.places[index].assetIdentifiers.contains(identifier)
                            Button {
                                draft.toggleAsset(identifier, for: placeID)
                                Task {
                                    if draft.photoImages[identifier] == nil,
                                       let image = await PhotoImageService.shared.image(for: identifier, targetSize: CGSize(width: 700, height: 700), highQuality: true) {
                                        draft.photoImages[identifier] = image
                                    }
                                }
                            } label: {
                                DraftPhotoView(identifier: identifier, images: draft.photoImages, size: CGSize(width: 200, height: 200))
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .overlay {
                                        if !selected { Color.black.opacity(0.28) }
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if selected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 21)).foregroundStyle(MRColor.accent)
                                                .background(Circle().fill(.white)).padding(5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("다른 장소에 있던 사진을 선택하면 이 장소로 이동합니다. 장소에는 최소 한 장의 사진이 남아야 합니다.")
                }

                Section("대표 사진") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(draft.places[index].assetIdentifiers, id: \.self) { identifier in
                                Button {
                                    draft.places[index].representativeAssetIdentifier = identifier
                                } label: {
                                    DraftPhotoView(identifier: identifier, images: draft.photoImages, size: CGSize(width: 180, height: 180))
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(draft.places[index].representativeAssetIdentifier == identifier ? MRColor.accent : Color.clear, lineWidth: 3)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(placeIndex.map { draft.places[$0].title } ?? "장소")
        .navigationBarTitleDisplayMode(.inline)
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

private struct InteractiveBoardPreview: View {
    @Bindable var draft: BoardDraft
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedPlaceID: UUID?
    @State private var page = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BoardCanvasView(model: draft.renderModel, watermark: false)

                ForEach(tappablePlacements(in: proxy.size)) { placement in
                    Button {
                        page = 0
                        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : MRMotion.spatial) {
                            expandedPlaceID = placement.place.id
                        }
                    } label: {
                        Color.clear
                            .frame(width: placement.hitSize.width, height: placement.hitSize.height)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .position(placement.center)
                    .accessibilityLabel("\(placement.place.title), 사진 \(placement.place.photoCount)장 펼치기")
                }

                if let place = draft.renderModel.visiblePlaces.first(where: { $0.id == expandedPlaceID }) {
                    expandedGallery(place, in: proxy.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.965)))
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("--ci-demo-gallery"),
                  expandedPlaceID == nil else { return }
            expandedPlaceID = draft.renderModel.visiblePlaces.first?.id
        }
    }

    private func tappablePlacements(in size: CGSize) -> [BoardTapPlacement] {
        if draft.template == .pinboard {
            return PinboardLayout.placements(model: draft.renderModel).map { placement in
                BoardTapPlacement(
                    place: placement.place,
                    center: CGPoint(x: placement.center.x * size.width, y: placement.center.y * size.height),
                    hitSize: CGSize(width: size.width * 0.29, height: size.height * 0.19)
                )
            }
        }

        return draft.renderModel.visiblePlaces.compactMap { place in
            guard let point = draft.normalizedPoints[place.id] else { return nil }
            return BoardTapPlacement(
                place: place,
                center: CGPoint(x: point.x * size.width, y: point.y * size.height),
                hitSize: CGSize(width: max(48, size.width * 0.15), height: max(48, size.width * 0.15))
            )
        }
    }

    private func expandedGallery(_ place: BoardPlace, in size: CGSize) -> some View {
        ZStack {
            MRColor.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MRMotion.spatial) {
                        expandedPlaceID = nil
                    }
                }

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(place.timeRangeText) · 사진 \(place.photoCount)장")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MRMotion.spatial) {
                            expandedPlaceID = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.28))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                TabView(selection: $page) {
                    ForEach(Array(place.assetIdentifiers.enumerated()), id: \.element) { index, identifier in
                        Group {
                            if let image = draft.photoImages[identifier] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                AssetThumbnailView(identifier: identifier, size: CGSize(width: 900, height: 900))
                                    .scaledToFit()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: size.height * 0.50)
            }
            .padding(18)
            .frame(width: size.width * 0.91)
            .background(Color(hex: 0x22231F))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.30), radius: 26, y: 14)
        }
    }
}

private struct BoardTapPlacement: Identifiable {
    let place: BoardPlace
    let center: CGPoint
    let hitSize: CGSize
    var id: UUID { place.id }
}

private struct PinboardPlacement: Identifiable {
    let place: BoardPlace
    let center: CGPoint
    let rotation: Double
    var id: UUID { place.id }
}

private enum PinboardLayout {
    static func placements(model: BoardRenderModel) -> [PinboardPlacement] {
        let places = Array(model.visiblePlaces.prefix(6))
        let fallback = [
            CGPoint(x: 0.20, y: 0.28), CGPoint(x: 0.76, y: 0.27),
            CGPoint(x: 0.76, y: 0.60), CGPoint(x: 0.24, y: 0.67),
            CGPoint(x: 0.67, y: 0.80), CGPoint(x: 0.34, y: 0.82)
        ]
        let nudges = [
            CGPoint(x: -0.045, y: -0.025), CGPoint(x: 0.050, y: -0.018),
            CGPoint(x: 0.042, y: 0.035), CGPoint(x: -0.045, y: 0.040),
            CGPoint(x: 0.030, y: 0.025), CGPoint(x: -0.025, y: 0.020)
        ]
        let rotations: [Double] = [-3.0, 2.2, -1.6, 2.7, -2.2, 1.6]
        var occupied: [CGPoint] = []
        var output: [PinboardPlacement] = []

        for (index, place) in places.enumerated() {
            let source = model.normalizedPoints[place.id] ?? fallback[index % fallback.count]
            var candidate = CGPoint(
                x: clamp(source.x + nudges[index % nudges.count].x, lower: 0.16, upper: 0.84),
                y: clamp(source.y + nudges[index % nudges.count].y, lower: 0.24, upper: 0.79)
            )

            var attempt = 0
            while occupied.contains(where: { distance($0, candidate) < 0.215 }) && attempt < fallback.count {
                let alternate = fallback[(index + attempt) % fallback.count]
                candidate = CGPoint(
                    x: clamp(alternate.x + nudges[index % nudges.count].x * 0.35, lower: 0.16, upper: 0.84),
                    y: clamp(alternate.y + nudges[index % nudges.count].y * 0.35, lower: 0.24, upper: 0.79)
                )
                attempt += 1
            }

            occupied.append(candidate)
            output.append(PinboardPlacement(place: place, center: candidate, rotation: rotations[index % rotations.count]))
        }
        return output
    }

    static func anchor(for placement: PinboardPlacement, in size: CGSize) -> CGPoint {
        let cardHeight = size.height * 0.165
        return CGPoint(
            x: placement.center.x * size.width,
            y: placement.center.y * size.height - cardHeight * 0.47
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(upper, max(lower, value))
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

struct BoardCanvasView: View {
    let model: BoardRenderModel
    let watermark: Bool

    var body: some View {
        GeometryReader { proxy in
            switch model.template {
            case .pinboard:
                pinboard(in: proxy.size)
            case .ribbon:
                ribbon(in: proxy.size)
            case .editorial:
                editorial(in: proxy.size)
            case .postcard:
                postcard(in: proxy.size)
            }
        }
        .background(MRColor.paper)
        .clipped()
    }

    private func pinboard(in size: CGSize) -> some View {
        let placements = PinboardLayout.placements(model: model)
        let anchors = placements.map { PinboardLayout.anchor(for: $0, in: size) }

        return ZStack {
            Image(uiImage: model.mapImage)
                .resizable()
                .scaledToFill()
                .saturation(0.56)
                .contrast(0.90)
                .brightness(0.035)

            Color(hex: 0xF3EBDD).opacity(0.19)

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.075)],
                center: .center,
                startRadius: size.width * 0.18,
                endRadius: size.width * 0.72
            )

            CottonThreadLayer(points: anchors, width: size.width)
            pinboardStacks(placements, size: size)
            header(size, usesPaperLabel: true)
            footer(size, dark: true)
        }
    }

    private func ribbon(in size: CGSize) -> some View {
        let anchors = mapAnchors(in: size)
        return ZStack {
            Image(uiImage: model.mapImage).resizable().scaledToFill().saturation(0.82)
            Color.white.opacity(0.08)
            CottonThreadLayer(points: anchors, width: size.width)
            mapPhotoPins(size)
            header(size, usesPaperLabel: true)
            footer(size, dark: true)
        }
    }

    private func editorial(in size: CGSize) -> some View {
        let mapHeight = size.height * 0.68
        let mapSize = CGSize(width: size.width, height: mapHeight)
        return ZStack(alignment: .top) {
            MRColor.paper
            VStack(spacing: 0) {
                ZStack {
                    Image(uiImage: model.mapImage).resizable().scaledToFill().saturation(0.78)
                    CottonThreadLayer(points: mapAnchors(in: mapSize), width: size.width)
                    mapPhotoPins(mapSize)
                }
                .frame(height: mapHeight)

                HStack(spacing: size.width * 0.018) {
                    ForEach(Array(model.visiblePlaces.prefix(4))) { place in
                        if let image = model.photoImages[place.representativeAssetIdentifier] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .clipped()
                        }
                    }
                }
                .frame(height: size.height * 0.22)
                .padding(size.width * 0.04)
            }
            header(size, usesPaperLabel: false)
            footer(size, dark: false)
        }
    }

    private func postcard(in size: CGSize) -> some View {
        ZStack {
            MRColor.paper
            Image(uiImage: model.mapImage)
                .resizable()
                .scaledToFill()
                .padding(size.width * 0.07)
                .overlay {
                    RoundedRectangle(cornerRadius: size.width * 0.012)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                        .padding(size.width * 0.07)
                }
            CottonThreadLayer(points: mapAnchors(in: size), width: size.width)
                .padding(size.width * 0.07)
            mapPhotoPins(size)
            header(size, usesPaperLabel: false)
            footer(size, dark: false)
        }
    }

    private func mapAnchors(in size: CGSize) -> [CGPoint] {
        model.visiblePlaces.compactMap { place in
            guard let point = model.normalizedPoints[place.id] else { return nil }
            return CGPoint(x: point.x * size.width, y: point.y * size.height)
        }
    }

    @ViewBuilder
    private func mapPhotoPins(_ size: CGSize) -> some View {
        ForEach(Array(model.visiblePlaces.enumerated()), id: \.element.id) { index, place in
            if let point = model.normalizedPoints[place.id],
               let image = model.photoImages[place.representativeAssetIdentifier] {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width * 0.105, height: size.width * 0.105)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(.white, lineWidth: size.width * 0.010) }
                        .shadow(color: .black.opacity(0.22), radius: size.width * 0.014, y: size.width * 0.008)

                    Text("\(index + 1)")
                        .font(.system(size: max(8, size.width * 0.024), weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: size.width * 0.047, height: size.width * 0.047)
                        .background(MRColor.accent)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(.white, lineWidth: 1.5) }

                    if place.photoCount > 1 {
                        Text("\(place.photoCount)장")
                            .font(.system(size: max(7, size.width * 0.019), weight: .bold))
                            .foregroundStyle(MRColor.ink)
                            .padding(.horizontal, size.width * 0.014)
                            .frame(height: size.width * 0.040)
                            .background(.white)
                            .clipShape(Capsule())
                            .offset(x: size.width * 0.018, y: -size.width * 0.070)
                    }
                }
                .position(x: point.x * size.width, y: point.y * size.height)
            }
        }
    }

    @ViewBuilder
    private func pinboardStacks(_ placements: [PinboardPlacement], size: CGSize) -> some View {
        ForEach(Array(placements.enumerated()), id: \.element.id) { index, placement in
            PinboardPhotoStack(
                place: placement.place,
                images: model.photoImages,
                cardWidth: size.width * 0.255,
                cardHeight: size.height * 0.165,
                rotation: placement.rotation,
                index: index
            )
            .position(x: placement.center.x * size.width, y: placement.center.y * size.height)
        }
    }

    private func header(_ size: CGSize, usesPaperLabel: Bool) -> some View {
        let content = VStack(alignment: .leading, spacing: size.height * 0.004) {
            Text(model.date.mrBoardDate)
                .font(.system(size: size.width * 0.026, weight: .semibold))
                .foregroundStyle(MRColor.ink.opacity(0.62))
            Text(model.title)
                .font(.system(size: size.width * 0.057, weight: .bold, design: model.template == .postcard ? .serif : .default))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .foregroundStyle(MRColor.ink)
            if !model.caption.isEmpty {
                Text(model.caption)
                    .font(.system(size: size.width * 0.027, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(MRColor.ink.opacity(0.64))
            }
        }
        .padding(usesPaperLabel ? size.width * 0.028 : 0)
        .frame(maxWidth: size.width * 0.62, alignment: .leading)
        .background {
            if usesPaperLabel {
                RoundedRectangle(cornerRadius: size.width * 0.014, style: .continuous)
                    .fill(Color(hex: 0xFFFDF8).opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: size.width * 0.014, style: .continuous)
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.10), radius: size.width * 0.016, y: size.width * 0.010)
            }
        }

        return content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .padding(.leading, size.width * 0.055)
            .padding(.top, size.height * 0.035)
    }

    private func footer(_ size: CGSize, dark: Bool) -> some View {
        HStack {
            Text("사진 \(model.photoCount)장 · 장소 \(model.visiblePlaces.count)곳")
            Spacer()
            if watermark { Text("Made with MapRibbon") }
        }
        .font(.system(size: size.width * 0.026, weight: .semibold))
        .foregroundStyle(dark ? Color.black.opacity(0.58) : MRColor.ink.opacity(0.64))
        .padding(.horizontal, size.width * 0.055)
        .padding(.bottom, size.height * 0.026)
        .frame(width: size.width, height: size.height, alignment: .bottom)
    }
}

private struct CottonThreadLayer: View {
    let points: [CGPoint]
    let width: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }

            for index in 0..<(points.count - 1) {
                let path = threadPath(from: points[index], to: points[index + 1], index: index)
                let baseWidth = max(3.2, width * 0.0082)

                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: .black.opacity(0.24), radius: width * 0.008, x: 0, y: width * 0.006))
                    layer.stroke(
                        path,
                        with: .color(Color(hex: 0x7F302C).opacity(0.76)),
                        style: StrokeStyle(lineWidth: baseWidth + width * 0.004, lineCap: .round, lineJoin: .round)
                    )
                }

                context.stroke(
                    path,
                    with: .color(Color(hex: 0xA83F36)),
                    style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    path,
                    with: .color(Color(hex: 0xD85A4C)),
                    style: StrokeStyle(lineWidth: baseWidth * 0.68, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(0.24)),
                    style: StrokeStyle(lineWidth: max(0.8, baseWidth * 0.17), lineCap: .round, lineJoin: .round)
                )
            }

            for point in points {
                let radius = width * 0.012
                var loop = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(
                    loop,
                    with: .color(Color(hex: 0xA83F36)),
                    style: StrokeStyle(lineWidth: max(2, width * 0.006), lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func threadPath(from start: CGPoint, to end: CGPoint, index: Int) -> Path {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let sag = min(width * 0.082, max(width * 0.025, length * 0.105)) * direction

        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + dx * 0.34 + normal.x * sag, y: start.y + dy * 0.34 + normal.y * sag),
            control2: CGPoint(x: start.x + dx * 0.70 + normal.x * sag * 0.72, y: start.y + dy * 0.70 + normal.y * sag * 0.72)
        )
        return path
    }
}

private struct PinboardPhotoStack: View {
    let place: BoardPlace
    let images: [String: UIImage]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let rotation: Double
    let index: Int

    private var orderedIdentifiers: [String] {
        let available = place.assetIdentifiers.filter { images[$0] != nil }
        guard !available.isEmpty else { return [] }
        let representative = place.representativeAssetIdentifier
        let supporting = available.filter { $0 != representative }.prefix(2)
        return Array(supporting) + (images[representative] == nil ? [] : [representative])
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(orderedIdentifiers.enumerated()), id: \.element) { itemIndex, identifier in
                let isFront = itemIndex == orderedIdentifiers.count - 1
                if let image = images[identifier] {
                    polaroid(image: image, isFront: isFront)
                        .rotationEffect(.degrees(cardRotation(itemIndex: itemIndex, isFront: isFront)))
                        .offset(cardOffset(itemIndex: itemIndex, isFront: isFront))
                }
            }

            PushpinView(size: cardWidth * 0.085, tint: pinColor)
                .offset(y: -cardHeight * 0.045)
        }
        .frame(width: cardWidth * 1.18, height: cardHeight * 1.13)
    }

    private func polaroid(image: UIImage, isFront: Bool) -> some View {
        VStack(alignment: .leading, spacing: cardHeight * 0.028) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth * 0.91, height: isFront ? cardHeight * 0.67 : cardHeight * 0.73)
                .clipped()

            if isFront {
                HStack(alignment: .firstTextBaseline, spacing: cardWidth * 0.03) {
                    VStack(alignment: .leading, spacing: cardHeight * 0.008) {
                        Text(place.title)
                            .lineLimit(1)
                            .font(.system(size: cardWidth * 0.070, weight: .bold))
                        Text(place.timeRangeText)
                            .font(.system(size: cardWidth * 0.052, weight: .medium))
                            .foregroundStyle(MRColor.ink.opacity(0.58))
                    }
                    Spacer(minLength: 0)
                    if place.photoCount > 1 {
                        Text("\(place.photoCount)장")
                            .font(.system(size: cardWidth * 0.050, weight: .bold))
                            .foregroundStyle(MRColor.accent)
                            .padding(.horizontal, cardWidth * 0.035)
                            .padding(.vertical, cardHeight * 0.012)
                            .background(MRColor.accentSoft)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(MRColor.ink.opacity(0.84))
            }
        }
        .padding(cardWidth * 0.045)
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
        .background(Color(hex: 0xFFFDF8))
        .overlay {
            Rectangle().stroke(Color.black.opacity(0.075), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isFront ? 0.18 : 0.12), radius: cardWidth * 0.045, y: cardWidth * 0.028)
    }

    private func cardRotation(itemIndex: Int, isFront: Bool) -> Double {
        if isFront { return rotation }
        return itemIndex.isMultiple(of: 2) ? rotation - 6.5 : rotation + 6.0
    }

    private func cardOffset(itemIndex: Int, isFront: Bool) -> CGSize {
        if isFront { return .zero }
        return itemIndex.isMultiple(of: 2)
            ? CGSize(width: -cardWidth * 0.070, height: cardHeight * 0.020)
            : CGSize(width: cardWidth * 0.070, height: cardHeight * 0.028)
    }

    private var pinColor: Color {
        let colors: [Color] = [Color(hex: 0xB74B3E), Color(hex: 0x365F72), Color(hex: 0xB27835), Color(hex: 0x5A6E48)]
        return colors[index % colors.count]
    }
}

private struct PushpinView: View {
    let size: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.16))
                .frame(width: size * 1.12, height: size * 1.12)
                .offset(y: size * 0.16)
            Circle()
                .fill(tint)
                .frame(width: size, height: size)
            Circle()
                .fill(Color.white.opacity(0.46))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(x: -size * 0.19, y: -size * 0.20)
        }
        .shadow(color: .black.opacity(0.22), radius: size * 0.18, y: size * 0.12)
    }
}

struct SavedBoardDetailView: View {
    let board: SavedBoard
    @State private var showingActivity = false
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let image = UIImage(data: board.previewImageData) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.10), radius: 15, y: 7)
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                do {
                                    try await PhotoSaveService.save(image)
                                    toastMessage = "사진 보관함에 저장했습니다."
                                } catch { toastMessage = error.localizedDescription }
                            }
                        } label: { Label("저장", systemImage: "square.and.arrow.down") }
                        .buttonStyle(MRSecondaryButtonStyle())
                        Button {
                            Task {
                                if !(await InstagramShareService.shareStory(image: image)) {
                                    toastMessage = "Instagram 앱을 열 수 없습니다."
                                }
                            }
                        } label: { Label("Instagram", systemImage: "camera") }
                        .buttonStyle(MRSecondaryButtonStyle())
                    }
                    Button { showingActivity = true } label: { Label("더 보기", systemImage: "square.and.arrow.up") }
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
        .alert("MapRibbon", isPresented: Binding(get: { toastMessage != nil }, set: { if !$0 { toastMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(toastMessage ?? "") }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
