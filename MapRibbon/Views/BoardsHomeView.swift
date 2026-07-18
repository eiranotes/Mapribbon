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
            VStack(spacing: 26) {
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

                Button {
                    showingAllDates = true
                } label: {
                    Label("새 핀보드 만들기", systemImage: "plus")
                }
                .buttonStyle(MRPrimaryButtonStyle())
                .disabled(!photoLibrary.canReadLibrary)

                if !boards.isEmpty {
                    recentBoards
                }
            }
            .padding(.horizontal, MRSpacing.screen)
            .padding(.bottom, 36)
        }
        .background(MRColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            photoLibrary.refreshAuthorization()
            if photoLibrary.canReadLibrary && photoLibrary.daySummaries.isEmpty {
                await photoLibrary.scanRecentDays()
            }
        }
        .refreshable {
            await photoLibrary.scanRecentDays()
        }
        .sheet(item: $selectedSummary) { summary in
            GenerationFlowView(summary: summary)
        }
        .sheet(isPresented: $showingAllDates) {
            NavigationStack {
                DateSelectionView { summary in
                    showingAllDates = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        selectedSummary = summary
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("보드")
                    .font(.system(size: 30, weight: .bold))
                Text("사진을 골라 하루의 장소를 한 장으로 엮어요")
                    .font(.system(size: 14))
                    .foregroundStyle(MRColor.secondaryText)
            }
            Spacer()
            MRStatusBadge(text: "로컬 처리", symbol: "lock")
        }
        .padding(.top, 18)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MRColor.accent)
            Text("사진 접근이 필요합니다")
                .font(.system(size: 20, weight: .bold))
            Text("위치가 포함된 사진의 날짜와 장소를 읽어 자동 핀보드를 만듭니다.")
                .font(.system(size: 14))
                .foregroundStyle(MRColor.secondaryText)
            Button("사진 접근 허용") {
                Task { await photoLibrary.requestAccess() }
            }
            .buttonStyle(MRSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mrCard()
    }

    private var scanningCard: some View {
        HStack(spacing: 14) {
            ProgressView().tint(MRColor.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("사진 보관함 확인 중")
                    .font(.system(size: 16, weight: .semibold))
                Text("위치가 있는 날짜만 빠르게 찾고 있습니다.")
                    .font(.system(size: 13))
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
                    MRStatusBadge(text: "최근 여행일", symbol: "sparkles")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MRColor.secondaryText)
                }

                HStack(spacing: 15) {
                    AssetThumbnailView(identifier: summary.thumbnailIdentifier, size: CGSize(width: 96, height: 96))
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.date.mrDayTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(MRColor.primaryText)
                        Text("사진 \(summary.photoCount)장 · 약 \(summary.estimatedPlaceCount)곳")
                            .font(.system(size: 14))
                            .foregroundStyle(MRColor.secondaryText)
                        Text("사진을 확인하고 만들기")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MRColor.accent)
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MRPressableCardStyle())
        .mrCard()
    }

    private var noPhotosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(MRColor.secondaryText)
            Text("위치 사진을 찾지 못했습니다")
                .font(.system(size: 19, weight: .bold))
            Text("카메라의 위치정보가 켜진 사진이 2장 이상 있는 날짜가 필요합니다.")
                .font(.system(size: 14))
                .foregroundStyle(MRColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mrCard()
    }

    private var recentBoards: some View {
        VStack(spacing: 14) {
            MRSectionHeader(title: "최근 보드", subtitle: "저장한 여행 핀보드")
            ForEach(boards.prefix(6)) { board in
                NavigationLink {
                    SavedBoardDetailView(board: board)
                } label: {
                    HStack(spacing: 14) {
                        if let image = UIImage(data: board.previewImageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(board.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MRColor.primaryText)
                            Text(board.date.mrDayTitle)
                                .font(.system(size: 13))
                                .foregroundStyle(MRColor.secondaryText)
                            Text("사진 \(board.photoCount)장 · 장소 \(board.placeCount)곳")
                                .font(.system(size: 12))
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MRColor.secondaryText)
                    }
                    .mrCard(padding: 12)
                }
                .buttonStyle(MRPressableCardStyle())
            }
        }
    }
}

struct DateSelectionView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    let onSelect: (PhotoDaySummary) -> Void

    var body: some View {
        List {
            if photoLibrary.isLimited {
                Section {
                    Button("접근 가능한 사진 추가") {
                        photoLibrary.showLimitedLibraryPicker()
                    }
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
                            AssetThumbnailView(identifier: summary.thumbnailIdentifier, size: CGSize(width: 62, height: 62))
                                .frame(width: 62, height: 62)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(summary.date.mrDayTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(MRColor.primaryText)
                                Text("사진 \(summary.photoCount)장 · 약 \(summary.estimatedPlaceCount)곳")
                                    .font(.system(size: 13))
                                    .foregroundStyle(MRColor.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(MRColor.secondaryText)
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
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
