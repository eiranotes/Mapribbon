from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


# Complete Korea/Japan region normalization.
path = Path("MapRibbon/Services/BoardGenerationService.swift")
text = path.read_text()
marker = "enum RegionNormalizer {"
prefix, separator, _ = text.partition(marker)
if not separator:
    raise SystemExit("RegionNormalizer marker not found")
replacement = r'''enum RegionNormalizer {
    private struct Mapping {
        let aliases: [String]
        let key: String
    }

    private static let mappings: [Mapping] = [
        Mapping(aliases: ["서울", "Seoul"], key: "서울"),
        Mapping(aliases: ["부산", "Busan"], key: "부산"),
        Mapping(aliases: ["대구", "Daegu"], key: "대구"),
        Mapping(aliases: ["인천", "Incheon"], key: "인천"),
        Mapping(aliases: ["광주", "Gwangju"], key: "광주"),
        Mapping(aliases: ["대전", "Daejeon"], key: "대전"),
        Mapping(aliases: ["울산", "Ulsan"], key: "울산"),
        Mapping(aliases: ["세종", "Sejong"], key: "세종"),
        Mapping(aliases: ["경기", "Gyeonggi"], key: "경기"),
        Mapping(aliases: ["강원", "Gangwon"], key: "강원"),
        Mapping(aliases: ["충청북", "North Chungcheong"], key: "충북"),
        Mapping(aliases: ["충청남", "South Chungcheong"], key: "충남"),
        Mapping(aliases: ["전북", "전라북", "North Jeolla"], key: "전북"),
        Mapping(aliases: ["전남", "전라남", "South Jeolla"], key: "전남"),
        Mapping(aliases: ["경상북", "North Gyeongsang"], key: "경북"),
        Mapping(aliases: ["경상남", "South Gyeongsang"], key: "경남"),
        Mapping(aliases: ["제주", "Jeju"], key: "제주"),

        Mapping(aliases: ["北海道", "Hokkaido"], key: "일본:홋카이도"),
        Mapping(aliases: ["青森", "Aomori", "岩手", "Iwate", "宮城", "Miyagi", "秋田", "Akita", "山形", "Yamagata", "福島", "Fukushima"], key: "일본:도호쿠"),
        Mapping(aliases: ["茨城", "Ibaraki", "栃木", "Tochigi", "群馬", "Gunma", "埼玉", "Saitama", "千葉", "Chiba", "東京", "Tokyo", "神奈川", "Kanagawa"], key: "일본:간토"),
        Mapping(aliases: ["新潟", "Niigata", "富山", "Toyama", "石川", "Ishikawa", "福井", "Fukui", "山梨", "Yamanashi", "長野", "Nagano", "岐阜", "Gifu", "静岡", "Shizuoka", "愛知", "Aichi"], key: "일본:주부"),
        Mapping(aliases: ["三重", "Mie", "滋賀", "Shiga", "京都", "Kyoto", "大阪", "Osaka", "兵庫", "Hyogo", "奈良", "Nara", "和歌山", "Wakayama"], key: "일본:간사이"),
        Mapping(aliases: ["鳥取", "Tottori", "島根", "Shimane", "岡山", "Okayama", "広島", "Hiroshima", "山口", "Yamaguchi"], key: "일본:주고쿠"),
        Mapping(aliases: ["徳島", "Tokushima", "香川", "Kagawa", "愛媛", "Ehime", "高知", "Kochi"], key: "일본:시코쿠"),
        Mapping(aliases: ["福岡", "Fukuoka", "佐賀", "Saga", "長崎", "Nagasaki", "熊本", "Kumamoto", "大分", "Oita", "Ōita", "宮崎", "Miyazaki", "鹿児島", "Kagoshima", "沖縄", "Okinawa"], key: "일본:규슈")
    ]

    static func key(from value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let normalizedValue = normalized(value)
        return mappings.first { mapping in
            mapping.aliases.contains { normalizedValue.contains(normalized($0)) }
        }?.key
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "prefecture", with: "")
            .replacingOccurrences(of: "metropolis", with: "")
            .replacingOccurrences(of: "province", with: "")
            .replacingOccurrences(of: "都", with: "")
            .replacingOccurrences(of: "道", with: "")
            .replacingOccurrences(of: "府", with: "")
            .replacingOccurrences(of: "県", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
'''
path.write_text(prefix + replacement)


# Preserve legacy atlas fallback pins and keep MapKit attribution unobstructed.
path = Path("MapRibbon/Views/AtlasSettingsViews.swift")
text = path.read_text()
text = replace_once(
    text,
    '    var total: Int { regions.count }\n',
    '    var total: Int { regions.count }\n    var regionKeys: [String] { regions.map(\\.key) }\n',
    "AtlasCountry.regionKeys"
)
text = replace_once(
    text,
    '''}

private struct AtlasVisit: Identifiable {
    let id: String
    let title: String
    let date: Date?
    let photoCount: Int
    let coordinate: CLLocationCoordinate2D
    let country: AtlasCountry
}
''',
    '''}

enum AtlasVisitCoverage {
    static func missingRegionKeys(
        visited: Set<String>,
        actual: Set<String>,
        country: AtlasCountry
    ) -> [String] {
        country.regionKeys.filter { visited.contains($0) && !actual.contains($0) }
    }
}

private struct AtlasVisit: Identifiable {
    let id: String
    let title: String
    let date: Date?
    let photoCount: Int
    let coordinate: CLLocationCoordinate2D
    let country: AtlasCountry
    let regionKey: String?
}
''',
    "AtlasVisitCoverage"
)
text = replace_once(
    text,
    '''                    coordinate: place.coordinate,
                    country: resolvedCountry
''',
    '''                    coordinate: place.coordinate,
                    country: resolvedCountry,
                    regionKey: RegionNormalizer.key(from: place.administrativeArea)
''',
    "decoded visit region"
)
text = replace_once(
    text,
    '''    private var mapVisits: [AtlasVisit] {
        let actual = decodedVisits.filter { $0.country == country }
        if !actual.isEmpty { return actual }
        return visibleRegions
            .filter { visited.contains($0.key) }
            .map {
                AtlasVisit(
                    id: "region-\($0.key)",
                    title: $0.name,
                    date: nil,
                    photoCount: 0,
                    coordinate: $0.coordinate,
                    country: country
                )
            }
    }
''',
    '''    private var mapVisits: [AtlasVisit] {
        let actual = decodedVisits.filter { $0.country == country }
        let actualRegionKeys = Set(actual.compactMap(\.regionKey))
        let fallbackRegionKeys = Set(
            AtlasVisitCoverage.missingRegionKeys(
                visited: visited,
                actual: actualRegionKeys,
                country: country
            )
        )
        let fallback = visibleRegions
            .filter { fallbackRegionKeys.contains($0.key) }
            .map {
                AtlasVisit(
                    id: "region-\($0.key)",
                    title: $0.name,
                    date: nil,
                    photoCount: 0,
                    coordinate: $0.coordinate,
                    country: country,
                    regionKey: $0.key
                )
            }
        return actual + fallback
    }
''',
    "mapVisits merge"
)
text = replace_once(
    text,
    '''            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(14)
            .allowsHitTesting(false)
''',
    '''            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 68)
            .padding(.leading, 14)
            .allowsHitTesting(false)
''',
    "atlas progress badge position"
)
path.write_text(text)


# Fit the editor to available height, preserve travel order, and allow toast dismissal.
path = Path("MapRibbon/Views/BoardViews.swift")
text = path.read_text()
text = replace_once(
    text,
    '''    var body: some View {
        VStack(spacing: 0) {
            BoardCanvasView(model: draft.renderModel, watermark: !store.isUnlocked)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.13), radius: 15, y: 8)

            Spacer(minLength: 0)
        }
        .background(MRScreenBackground())
''',
    '''    var body: some View {
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
''',
    "editor layout"
)
text = replace_once(
    text,
    '        let regions = Array(Set(draft.places.compactMap { RegionNormalizer.key(from: $0.administrativeArea) })).sorted()\n',
    '        let regions = BoardRegionSummary.regionKeys(from: draft.places)\n',
    "ordered region keys"
)
text = replace_once(
    text,
    '        guard let primaryRegion = regions.first else { return nil }\n',
    '        guard let primaryRegion = BoardRegionSummary.primaryRegion(from: draft.places) else { return nil }\n',
    "primary region"
)
text = replace_once(
    text,
    'private struct BoardSaveOutcome {\n',
    '''enum BoardRegionSummary {
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
''',
    "BoardRegionSummary"
)
text = replace_once(
    text,
    '''            if notice.outcome != nil {
                Button("아틀라스 보기", action: onAtlas)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MRColor.accent)
            } else {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MRColor.secondaryText)
                }
                .accessibilityLabel("닫기")
            }
''',
    '''            if notice.outcome != nil {
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
''',
    "toast dismissal"
)
path.write_text(text)


# Regression tests for region mapping, legacy fallback, and ordered summaries.
path = Path("MapRibbonTests/PhotoClustererTests.swift")
text = path.read_text()
marker = '    private var sampleGeoPoints: [CGPoint] {\n'
tests = r'''    func testRegionNormalizerCoversAllJapanesePrefectures() {
        let samples: [(String, String)] = [
            ("北海道", "일본:홋카이도"),
            ("青森県", "일본:도호쿠"), ("岩手県", "일본:도호쿠"), ("宮城県", "일본:도호쿠"), ("秋田県", "일본:도호쿠"), ("山形県", "일본:도호쿠"), ("福島県", "일본:도호쿠"),
            ("茨城県", "일본:간토"), ("栃木県", "일본:간토"), ("群馬県", "일본:간토"), ("埼玉県", "일본:간토"), ("千葉県", "일본:간토"), ("東京都", "일본:간토"), ("神奈川県", "일본:간토"),
            ("新潟県", "일본:주부"), ("富山県", "일본:주부"), ("石川県", "일본:주부"), ("福井県", "일본:주부"), ("山梨県", "일본:주부"), ("長野県", "일본:주부"), ("岐阜県", "일본:주부"), ("静岡県", "일본:주부"), ("愛知県", "일본:주부"),
            ("三重県", "일본:간사이"), ("滋賀県", "일본:간사이"), ("京都府", "일본:간사이"), ("大阪府", "일본:간사이"), ("兵庫県", "일본:간사이"), ("奈良県", "일본:간사이"), ("和歌山県", "일본:간사이"),
            ("鳥取県", "일본:주고쿠"), ("島根県", "일본:주고쿠"), ("岡山県", "일본:주고쿠"), ("広島県", "일본:주고쿠"), ("山口県", "일본:주고쿠"),
            ("徳島県", "일본:시코쿠"), ("香川県", "일본:시코쿠"), ("愛媛県", "일본:시코쿠"), ("高知県", "일본:시코쿠"),
            ("福岡県", "일본:규슈"), ("佐賀県", "일본:규슈"), ("長崎県", "일본:규슈"), ("熊本県", "일본:규슈"), ("大分県", "일본:규슈"), ("宮崎県", "일본:규슈"), ("鹿児島県", "일본:규슈"), ("沖縄県", "일본:규슈")
        ]

        XCTAssertEqual(samples.count, 47)
        for (administrativeArea, expected) in samples {
            XCTAssertEqual(RegionNormalizer.key(from: administrativeArea), expected, administrativeArea)
        }
    }

    func testRegionNormalizerAcceptsEnglishPrefectureNames() {
        XCTAssertEqual(RegionNormalizer.key(from: "Toyama Prefecture"), "일본:주부")
        XCTAssertEqual(RegionNormalizer.key(from: "Wakayama Prefecture"), "일본:간사이")
        XCTAssertEqual(RegionNormalizer.key(from: "Yamaguchi Prefecture"), "일본:주고쿠")
        XCTAssertEqual(RegionNormalizer.key(from: "Kochi Prefecture"), "일본:시코쿠")
        XCTAssertEqual(RegionNormalizer.key(from: "Oita Prefecture"), "일본:규슈")
    }

    func testBoardRegionSummaryPreservesVisibleTravelOrder() {
        let places = [
            makePlace(title: "숨김", administrativeArea: "서울특별시", isHidden: true),
            makePlace(title: "오사카", administrativeArea: "Osaka Prefecture"),
            makePlace(title: "도쿄", administrativeArea: "Tokyo Metropolis"),
            makePlace(title: "교토", administrativeArea: "京都府")
        ]

        XCTAssertEqual(BoardRegionSummary.regionKeys(from: places), ["일본:간사이", "일본:간토"])
        XCTAssertEqual(BoardRegionSummary.primaryRegion(from: places), "일본:간사이")
    }

    func testAtlasCoverageKeepsLegacyFallbackRegions() {
        let missing = AtlasVisitCoverage.missingRegionKeys(
            visited: ["일본:간토", "일본:간사이", "일본:규슈"],
            actual: ["일본:간토"],
            country: .japan
        )
        XCTAssertEqual(missing, ["일본:간사이", "일본:규슈"])
    }

'''
text = replace_once(text, marker, tests + marker, "new tests")
helper_marker = '    private func make(id: String, date: Date, latitude: Double, longitude: Double) -> PhotoAssetSnapshot {\n'
helper = r'''    private func makePlace(
        title: String,
        administrativeArea: String,
        isHidden: Bool = false
    ) -> BoardPlace {
        let identifier = UUID().uuidString
        return BoardPlace(
            id: UUID(),
            title: title,
            subtitle: nil,
            caption: nil,
            addressSummary: administrativeArea,
            administrativeArea: administrativeArea,
            locality: nil,
            latitude: 35.0,
            longitude: 135.0,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_003_600),
            assetIdentifiers: [identifier],
            representativeAssetIdentifier: identifier,
            isHidden: isHidden
        )
    }

'''
text = replace_once(text, helper_marker, helper + helper_marker, "test helper")
path.write_text(text)
