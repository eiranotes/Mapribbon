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
            VStack(spacing: MRSpacing.section) {
                header

                Group {
                    if !photoLibrary.canReadLibrary {
                        permissionStart
                    } else if photoLibrary.isScanning {
                        scanningState
                    } else if let recommended = photoLibrary.daySummaries.first {
                        travelDayStart(recommended)
                    } else {
                        noPhotosState
                    }
                }

                if photoLibrary.canReadLibrary, !photoLibrary.daySummaries.isEmpty {
                    // 도판과 도판 사이를 실이 잇는다.
                    MRVerticalStitch()
                        .padding(.vertical, -18)

                    Button {
                        showingAllDates = true
                    } label: {
                        Label("다른 날짜 찾아보기", systemImage: "calendar")
                    }
                    .buttonStyle(MRSecondaryButtonStyle())
                }

                if !boards.isEmpty {
                    recentBoards
                }

                Label("사진과 위치정보는 기기 안에서만 처리됩니다.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(MRColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, MRSpacing.screen)
        }
        .background(MRScreenBackground())
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                MREyebrow(text: "MapRibbon — Day Route Atlas")
                Text("어느 하루를\n엮을까요?")
                    .font(MRType.display(31))
                    .tracking(-0.4)
                    .lineSpacing(2)
                    .foregroundStyle(MRColor.primaryText)
                Text("사진의 시간과 장소로 여행 보드를 만듭니다")
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
                    .padding(.top, 2)
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
                    .overlay { Circle().stroke(MRColor.frameInk.opacity(0.4), lineWidth: 0.9) }
            }
            .buttonStyle(MRPressableStyle())
            .accessibilityLabel("설정")
        }
        .padding(.top, 16)
    }

    private var permissionStart: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "photo.stack")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(MRColor.accent)
                    .frame(width: 48, height: 48)
                    .background(MRColor.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("사진에서 여행한 하루 찾기")
                        .font(.title3.weight(.bold))
                    Text("현재 위치가 아니라 사진에 저장된 날짜와 장소만 읽습니다.")
                        .font(.subheadline)
                        .foregroundStyle(MRColor.secondaryText)
                }
            }

            RoutePreviewStrip(identifiers: [])

            Button("사진 접근 계속") {
                Task { await photoLibrary.requestAccess() }
            }
            .buttonStyle(MRPrimaryButtonStyle())
        }
        .mrPlate(padding: 18)
    }

    private var scanningState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView().tint(MRColor.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("여행한 날짜를 찾고 있습니다")
                        .font(.headline)
                    Text("위치가 포함된 사진만 기기 안에서 빠르게 확인합니다.")
                        .font(.footnote)
                        .foregroundStyle(MRColor.secondaryText)
                }
            }
            MRRouteThread(progress: 0.58)
        }
        .mrPlate(padding: 18)
    }

    private func travelDayStart(_ summary: PhotoDaySummary) -> some View {
        VStack(spacing: 0) {
            Button {
                selectedSummary = summary
            } label: {
                VStack(alignment: .leading, spacing: 17) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            MREyebrow(text: "Field Day — 추천 여행일")
                            Text(summary.date.mrDayTitle)
                                .font(MRType.plate(23, weight: .bold))
                                .foregroundStyle(MRColor.primaryText)
                        }
                        Spacer()
                        Text("\(summary.photoCount)장 · 약 \(summary.estimatedPlaceCount)곳")
                            .font(MRType.plate(13).monospacedDigit())
                            .foregroundStyle(MRColor.secondaryText)
                    }

                    RoutePreviewStrip(identifiers: Array(summary.assets.prefix(3).map(\.id)))

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("이 하루로 보드 만들기")
                                .font(.headline)
                                .foregroundStyle(MRColor.primaryText)
                            Text("사진 순서와 지도를 자동으로 엮습니다")
                                .font(.footnote)
                                .foregroundStyle(MRColor.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(MRColor.accent)
                            .clipShape(Circle())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MRPressableStyle())
            .mrPlate(padding: 18)
            .overlay(alignment: .top) {
                MRPinDot()
                    .offset(y: -4)
            }
        }
    }

    private var noPhotosState: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: "mappin.slash")
                .font(.title2.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
            Text("아직 엮을 여행일을 찾지 못했습니다")
                .font(.title3.weight(.bold))
            Text("위치정보가 켜진 사진이 두 장 이상 있는 날짜가 필요합니다. 아래로 당겨 다시 확인할 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(MRColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mrPlate(padding: 18)
    }

    private var recentBoards: some View {
        VStack(spacing: 14) {
            MRSectionHeader(title: "최근 보드", subtitle: "완성한 여행 기록")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(boards.prefix(6)) { board in
                        NavigationLink {
                            SavedBoardDetailView(board: board)
                        } label: {
                            BoardPosterCard(board: board, width: 152)
                        }
                        .buttonStyle(MRPressableStyle())
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
}

private struct RoutePreviewStrip: View {
    let identifiers: [String]

    var body: some View {
        ZStack {
            MRRouteThread(progress: 1)
                .padding(.horizontal, 34)
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Group {
                        if identifiers.indices.contains(index) {
                            AssetThumbnailView(identifier: identifiers[index], size: CGSize(width: 74, height: 74))
                        } else {
                            MRPhotoPlaceholder()
                        }
                    }
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                    .rotationEffect(.degrees([-3, 2, -1][index]))
                    if index < 2 { Spacer(minLength: 18) }
                }
            }
        }
        .frame(height: 88)
        .accessibilityHidden(true)
    }
}

struct BoardLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedBoard.createdAt, order: .reverse) private var boards: [SavedBoard]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var groupedBoards: [(String, [SavedBoard])] {
        let groups = Dictionary(grouping: boards) { $0.date.mrMonthSection }
        return groups
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { lhs, rhs in
                guard let ld = lhs.1.first?.date, let rd = rhs.1.first?.date else { return lhs.0 > rhs.0 }
                return ld > rd
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MRSpacing.section) {
                libraryHeader

                if boards.isEmpty {
                    emptyLibrary
                } else {
                    ForEach(groupedBoards, id: \.0) { month, monthBoards in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Text(month)
                                    .font(MRType.plate(16, weight: .bold).monospacedDigit())
                                    .foregroundStyle(MRColor.primaryText)
                                MRStitch(color: MRColor.frameInk.opacity(0.4))
                            }

                            LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                                ForEach(monthBoards) { board in
                                    NavigationLink {
                                        SavedBoardDetailView(board: board)
                                    } label: {
                                        BoardPosterCard(board: board)
                                    }
                                    .buttonStyle(MRPressableStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            modelContext.delete(board)
                                            try? modelContext.save()
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, MRSpacing.screen)
            .padding(.bottom, 40)
        }
        .background(MRScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var libraryHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                MREyebrow(text: "Archive — 여행 도판집")
                Text("보관함")
                    .font(MRType.display(31))
                    .tracking(-0.4)
                    .foregroundStyle(MRColor.primaryText)
                Text("완성한 여행 보드를 날짜별로 모았습니다")
                    .font(.subheadline)
                    .foregroundStyle(MRColor.secondaryText)
                    .padding(.top, 2)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(MRColor.primaryText)
                    .frame(width: 44, height: 44)
                    .background(MRColor.elevatedSurface)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(MRColor.border.opacity(0.8), lineWidth: 0.7) }
            }
            .buttonStyle(MRPressableStyle())
        }
        .padding(.top, 16)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(MRColor.accent)
            Text("아직 저장한 보드가 없습니다")
                .font(.title3.weight(.bold))
            Text("보드 탭에서 여행한 날짜를 선택하면 완성한 기록이 이곳에 쌓입니다.")
                .font(.subheadline)
                .foregroundStyle(MRColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 86)
    }
}

private struct BoardPosterCard: View {
    let board: SavedBoard
    var width: CGFloat? = nil

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
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(4)
            .background(MRColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay { MRPlateFrame(cornerRadius: 9) }
            .overlay(alignment: .top) { MRPinDot(diameter: 9).offset(y: -3) }
            .shadow(color: .black.opacity(0.14), radius: 8, y: 5)

            Text(board.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MRColor.primaryText)
                .lineLimit(1)
            Text("\(board.date.mrDayTitle) · \(board.photoCount)장")
                .font(MRType.plate(11).monospacedDigit())
                .foregroundStyle(MRColor.secondaryText)
                .lineLimit(1)
        }
        .frame(width: width)
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
                                    .font(.footnote.monospacedDigit())
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                MRPhotoPlaceholder()
            }
        }
        .task(id: identifier) {
            guard let identifier else { return }
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = result.firstObject else { return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: size.width * 2, height: size.height * 2),
                contentMode: .aspectFill,
                options: options
            ) { value, _ in
                if let value { image = value }
            }
        }
    }
}
