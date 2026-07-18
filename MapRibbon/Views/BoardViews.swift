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
                                Label("사진·경로", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
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

                    HStack(spacing: 10) {
                        ExportActionButton(title: "저장", symbol: "square.and.arrow.down") {
                            Task { if let image = await render() { onExport(image, .save) } }
                        }
                        ExportActionButton(title: "Instagram", symbol: "camera") {
                            Task { if let image = await render() { onExport(image, .instagram) } }
                        }
                        ExportActionButton(title: "더 보기", symbol: "square.and.arrow.up") {
                            Task { if let image = await render() { onExport(image, .share) } }
                        }
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
                                AssetThumbnailView(identifier: place.representativeAssetIdentifier, size: CGSize(width: 58, height: 58))
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
            .navigationTitle("사진과 경로")
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
                                AssetThumbnailView(identifier: identifier, size: CGSize(width: 200, height: 200))
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
                                    AssetThumbnailView(identifier: identifier, size: CGSize(width: 180, height: 180))
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
    @Namespace private var namespace

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BoardCanvasView(model: draft.renderModel, watermark: false)

                ForEach(draft.renderModel.visiblePlaces) { place in
                    if let point = draft.normalizedPoints[place.id] {
                        Button {
                            page = 0
                            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : MRMotion.spatial) {
                                expandedPlaceID = place.id
                            }
                        } label: {
                            Color.clear
                                .frame(width: max(48, proxy.size.width * 0.14), height: max(48, proxy.size.width * 0.14))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
                        .accessibilityLabel("\(place.title), 사진 \(place.photoCount)장 펼치기")
                    }
                }

                if let place = draft.renderModel.visiblePlaces.first(where: { $0.id == expandedPlaceID }) {
                    expandedGallery(place, in: proxy.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
    }

    private func expandedGallery(_ place: BoardPlace, in size: CGSize) -> some View {
        ZStack {
            MRColor.scrim
                .onTapGesture {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MRMotion.spatial) { expandedPlaceID = nil }
                }

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Text("\(place.timeRangeText) · \(place.photoCount)장")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MRMotion.spatial) { expandedPlaceID = nil }
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.black.opacity(0.25)).clipShape(Circle())
                    }
                }

                TabView(selection: $page) {
                    ForEach(Array(place.assetIdentifiers.enumerated()), id: \.element) { index, identifier in
                        Group {
                            if let image = draft.photoImages[identifier] {
                                Image(uiImage: image).resizable().scaledToFit()
                            } else {
                                AssetThumbnailView(identifier: identifier, size: CGSize(width: 800, height: 800))
                                    .scaledToFit()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: size.height * 0.48)
            }
            .padding(18)
            .frame(width: size.width * 0.90)
            .background(Color(hex: 0x22231F))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
        }
    }
}

struct BoardCanvasView: View {
    let model: BoardRenderModel
    let watermark: Bool

    var body: some View {
        GeometryReader { proxy in
            switch model.template {
            case .pinboard: pinboard(in: proxy.size)
            case .ribbon: ribbon(in: proxy.size)
            case .editorial: editorial(in: proxy.size)
            case .postcard: postcard(in: proxy.size)
            }
        }
        .background(MRColor.paper)
        .clipped()
    }

    private func pinboard(in size: CGSize) -> some View {
        ZStack {
            Image(uiImage: model.mapImage).resizable().scaledToFill().saturation(0.70).contrast(0.92)
            Color(hex: 0xF4EFE5).opacity(0.18)
            threadLayer(size)
            mapPhotoPins(size)
            pinboardCards(size)
            header(size, dark: true)
            footer(size, dark: true)
        }
    }

    private func ribbon(in size: CGSize) -> some View {
        ZStack {
            Image(uiImage: model.mapImage).resizable().scaledToFill()
            Color.white.opacity(0.10)
            threadLayer(size)
            mapPhotoPins(size)
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
                    threadLayer(CGSize(width: size.width, height: size.height * 0.68))
                    mapPhotoPins(CGSize(width: size.width, height: size.height * 0.68))
                }
                .frame(height: size.height * 0.68)
                HStack(spacing: size.width * 0.018) {
                    ForEach(Array(model.visiblePlaces.prefix(4))) { place in
                        if let image = model.photoImages[place.representativeAssetIdentifier] {
                            Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).clipped()
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
            threadLayer(size).padding(size.width * 0.07)
            mapPhotoPins(size)
            header(size, dark: false)
            footer(size, dark: false)
        }
    }

    @ViewBuilder private func threadLayer(_ size: CGSize) -> some View {
        Canvas { context, canvas in
            let places = model.visiblePlaces
            guard let first = places.first, let firstPoint = model.normalizedPoints[first.id] else { return }
            var path = Path()
            path.move(to: CGPoint(x: firstPoint.x * canvas.width, y: firstPoint.y * canvas.height))
            for place in places.dropFirst() {
                guard let point = model.normalizedPoints[place.id] else { continue }
                let destination = CGPoint(x: point.x * canvas.width, y: point.y * canvas.height)
                path.addLine(to: destination)
            }
            context.stroke(
                path,
                with: .color(MRColor.thread),
                style: StrokeStyle(lineWidth: max(2.5, canvas.width * 0.007), lineCap: .round, lineJoin: .round)
            )
        }
    }

    @ViewBuilder private func mapPhotoPins(_ size: CGSize) -> some View {
        ForEach(Array(model.visiblePlaces.enumerated()), id: \.element.id) { index, place in
            if let point = model.normalizedPoints[place.id],
               let image = model.photoImages[place.representativeAssetIdentifier] {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image).resizable().scaledToFill()
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
                        Text("+\(place.photoCount - 1)")
                            .font(.system(size: max(7, size.width * 0.019), weight: .bold))
                            .foregroundStyle(MRColor.ink)
                            .padding(.horizontal, size.width * 0.014)
                            .frame(height: size.width * 0.040)
                            .background(.white)
                            .clipShape(Capsule())
                            .offset(x: size.width * 0.014, y: -size.width * 0.070)
                    }
                }
                .position(x: point.x * size.width, y: point.y * size.height)
            }
        }
    }

    @ViewBuilder private func pinboardCards(_ size: CGSize) -> some View {
        let positions = cardPositions(count: min(5, model.visiblePlaces.count))
        ForEach(Array(model.visiblePlaces.prefix(5).enumerated()), id: \.element.id) { index, place in
            if index < positions.count, let image = model.photoImages[place.representativeAssetIdentifier] {
                VStack(alignment: .leading, spacing: size.height * 0.006) {
                    Image(uiImage: image).resizable().scaledToFill().clipped()
                    HStack {
                        Text(place.title).lineLimit(1)
                        Spacer()
                        Text(place.startDate.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.system(size: size.width * 0.021, weight: .semibold))
                    .foregroundStyle(MRColor.ink.opacity(0.78))
                }
                .padding(size.width * 0.012)
                .background(.white)
                .frame(width: size.width * 0.21, height: size.height * 0.16)
                .shadow(color: .black.opacity(0.16), radius: size.width * 0.014, y: size.width * 0.009)
                .rotationEffect(.degrees([-4, 3, -2, 4, -3][index]))
                .position(x: positions[index].x * size.width, y: positions[index].y * size.height)
            }
        }
    }

    private func header(_ size: CGSize, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: size.height * 0.004) {
            Text(model.date.mrBoardDate.uppercased())
                .font(.system(size: size.width * 0.030, weight: .semibold))
            Text(model.title)
                .font(.system(size: size.width * 0.068, weight: .bold, design: model.template == .postcard ? .serif : .default))
                .lineLimit(2)
            if !model.caption.isEmpty {
                Text(model.caption)
                    .font(.system(size: size.width * 0.030, weight: .medium))
                    .lineLimit(2)
                    .opacity(0.72)
            }
        }
        .foregroundStyle(dark ? Color.black.opacity(0.82) : MRColor.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.width * 0.065)
        .padding(.top, size.height * 0.045)
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
            .padding(.bottom, size.height * 0.030)
        }
    }

    private func cardPositions(count: Int) -> [CGPoint] {
        let all = [
            CGPoint(x: 0.20, y: 0.25), CGPoint(x: 0.78, y: 0.24),
            CGPoint(x: 0.76, y: 0.61), CGPoint(x: 0.22, y: 0.67),
            CGPoint(x: 0.66, y: 0.82)
        ]
        return Array(all.prefix(max(0, min(count, all.count))))
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
