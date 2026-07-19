import SwiftUI
import SwiftData
import Photos

struct BoardsHomeView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Query(sort: \SavedBoard.createdAt, order: .reverse) private var boards: [SavedBoard]

    @State private var selectedSummary: PhotoDaySummary?
    @State private var showingAllDates = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if !photoLibrary.canReadLibrary {
                    permissionCard
                } else if photoLibrary.isScanning {
                    scanningCard
                } else if let recommended = photoLibrary.daySummaries.first {
                    recommendedCard(recommended)
                } else {
                    noPhotosCard
                }

                if photoLibrary.canReadLibrary {
                    Button {
                        showingAllDates = true
                    } label: {
                        Label("새 보드 만들기", systemImage: "plus")
                    }
                    .buttonStyle(MRPrimaryButtonStyle())
                }

                if !boards.isEmpty {
                    recentBoards
                }

                Label("사진과 위치정보는 기기 안에서만 처리됩니다.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, MRSpacing.screen)
        }
        .background(MRColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            photoLibrary.refreshAuthorization()
            if photoLibrary.canReadLibrary && photoLibrary.daySummaries.isEmpty {
                await photoLibrary.scanRecentDays()
            }
        }
        .refreshable { await photoLibrary.scanRecentDays() }
        .sheet(item: $selectedSummary) { summary in
            GenerationFlowView(summary: summary)
        }
        .sheet(isPresented: $showingAllDates) {
            NavigationStack {
                DateSelectionView { summary in
                    showingAllDates = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        selectedSummary = summary
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("보드")
                    .font(.largeTitle.weight(.bold))
                Text("여행한 하루를 한 장으로 남겨요")
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(MRColor.primaryText)
                    .frame(width: 44, height: 44)
                    .background(MRColor.elevatedSurface)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(MRColor.border.opacity(0.55), lineWidth: 0.7) }
            }
            .buttonStyle(MRPressableStyle())
            .accessibilityLabel("설정")
        }
        .padding(.top, 14)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(MRColor.accent)
                    .frame(width: 46, height: 46)
                    .background(MRColor.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text("사진 접근이 필요합니다")
                        .font(.title3.weight(.bold))
                    Text("위치가 포함된 사진의 날짜와 장소를 읽어 자동 보드를 만듭니다.")
                        .font(.subheadline)
                        .foregroundStyle(MRColor.secondaryText)
                }
            }

            Button("사진 접근 허용") {
                Task { await photoLibrary.requestAccess() }
            }
            .buttonStyle(MRPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mrCard()
    }

    private var scanningCard: some View {
        HStack(spacing: 14) {
            ProgressView().tint(MRColor.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("사진 보관함 확인 중")
                    .font(.headline)
                Text("위치가 있는 날짜만 빠르게 찾고 있습니다.")
                    .font(.footnote)
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
        }
        .mrCard()
    }

    private func recommendedCard(_ summary: PhotoDaySummary) -> some View {
        Button {
            selectedSummary = summary
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MRStatusBadge(text: "오늘의 추천", symbol: "sparkles")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                }

                HStack(spacing: 15) {
                    AssetThumbnailView(identifier: summary.thumbnailIdentifier, size: CGSize(width: 108, height: 108))
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(summary.date.mrDayTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MRColor.primaryText)
                        Text("사진 \(summary.photoCount)장 · 약 \(summary.estimatedPlaceCount)곳")
                            .font(.subheadline)
                            .foregroundStyle(MRColor.secondaryText)
                        Text("이 날짜로 바로 만들기")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MRColor.accent)
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MRPressableStyle())
        .mrCard()
    }

    private var noPhotosCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: "mappin.slash")
                .font(.title2.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
            Text("위치 사진을 찾지 못했습니다")
                .font(.title3.weight(.bold))
            Text("카메라의 위치정보가 켜진 사진이 2장 이상 있는 날짜가 필요합니다.")
                .font(.subheadline)
                .foregroundStyle(MRColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mrCard()
    }

    private var recentBoards: some View {
        VStack(spacing: 13) {
            MRSectionHeader(title: "최근 보드", subtitle: "저장한 여행을 다시 열어보세요", trailing: "보관함")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(boards.prefix(5)) { board in
                        NavigationLink {
                            SavedBoardDetailView(board: board)
                        } label: {
                            BoardPosterCard(board: board)
                                .frame(width: 150)
                        }
                        .buttonStyle(MRPressableStyle())
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct BoardLibraryView: View {
    @Query(sort: \SavedBoard.createdAt, order: .reverse) private var boards: [SavedBoard]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("보관함").font(.largeTitle.weight(.bold))
                        Text("저장한 여행 보드를 모아봅니다")
                            .font(.subheadline)
                            .foregroundStyle(MRColor.secondaryText)
                    }
                    Spacer()
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(width: 44, height: 44)
                            .background(MRColor.elevatedSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(MRPressableStyle())
                }
                .padding(.top, 14)

                if boards.isEmpty {
                    ContentUnavailableView(
                        "아직 저장한 보드가 없습니다",
                        systemImage: "books.vertical",
                        description: Text("보드를 저장하면 날짜순으로 이곳에 쌓입니다.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(boards) { board in
                            NavigationLink {
                                SavedBoardDetailView(board: board)
                            } label: {
                                BoardPosterCard(board: board)
                            }
                            .buttonStyle(MRPressableStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, MRSpacing.screen)
            .padding(.bottom, 36)
        }
        .background(MRColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BoardPosterCard: View {
    let board: SavedBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Group {
                if let image = UIImage(data: board.previewImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    MRPhotoPlaceholder()
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .black.opacity(0.11), radius: 8, y: 4)

            Text(board.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MRColor.primaryText)
                .lineLimit(1)
            Text(board.date.mrDayTitle)
                .font(.caption)
                .foregroundStyle(MRColor.secondaryText)
        }
        .padding(10)
        .background(MRColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(MRColor.border.opacity(0.55), lineWidth: 0.7) }
    }
}

struct DateSelectionView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    let onSelect: (PhotoDaySummary) -> Void

    var body: some View {
        List {
            if photoLibrary.isLimited {
                Section {
                    Button("접근 가능한 사진 추가") { photoLibrary.showLimitedLibraryPicker() }
                } footer: {
                    Text("현재 선택한 사진만 분석하고 있습니다.")
                }
            }

            Section("위치 사진이 있는 날짜") {
                ForEach(photoLibrary.daySummaries) { summary in
                    Button {
                        onSelect(summary)
                    } label: {
                        HStack(spacing: 12) {
                            AssetThumbnailView(identifier: summary.thumbnailIdentifier, size: CGSize(width: 64, height: 64))
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(summary.date.mrDayTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MRColor.primaryText)
                                Text("사진 \(summary.photoCount)장 · 약 \(summary.estimatedPlaceCount)곳")
                                    .font(.footnote)
                                    .foregroundStyle(MRColor.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(MRColor.tertiaryText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MRColor.background)
        .navigationTitle("날짜 선택")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if photoLibrary.daySummaries.isEmpty {
                await photoLibrary.scanRecentDays()
            }
        }
    }
}

struct AssetThumbnailView: View {
    let identifier: String?
    let size: CGSize
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                MRPhotoPlaceholder()
            }
        }
        .task(id: identifier) {
            guard let identifier else { return }
            image = await PhotoImageService.shared.image(for: identifier, targetSize: size)
        }
    }
}
