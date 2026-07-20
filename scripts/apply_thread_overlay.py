from pathlib import Path

ROOT = Path('.')

def replace(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'missing pattern in {path}: {old[:100]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')

models = 'MapRibbon/Models/Models.swift'
replace(models, 'enum ExportFormat: String, CaseIterable, Identifiable {', '''enum BoardThreadColor: String, CaseIterable, Codable, Identifiable {
    case vermilion, indigo, forest, ochre, charcoal, rose

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vermilion: return "주홍"
        case .indigo: return "남색"
        case .forest: return "숲색"
        case .ochre: return "황토"
        case .charcoal: return "먹색"
        case .rose: return "장미"
        }
    }
    var primaryHex: UInt {
        switch self {
        case .vermilion: return 0xA43A2F
        case .indigo: return 0x36506E
        case .forest: return 0x3F654F
        case .ochre: return 0xA56B2A
        case .charcoal: return 0x4B4B49
        case .rose: return 0xA64C62
        }
    }
    var highlightHex: UInt {
        switch self {
        case .vermilion: return 0xE58B76
        case .indigo: return 0x8DA6C1
        case .forest: return 0x8FAF98
        case .ochre: return 0xD9A767
        case .charcoal: return 0xA8A8A2
        case .rose: return 0xD895A5
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {''')
replace(models, '    let template: BoardTemplate\n    let mapImage: UIImage', '    let template: BoardTemplate\n    let threadColor: BoardThreadColor\n    let mapImage: UIImage')
replace(models, '    var template: BoardTemplate\n    var mapImage: UIImage', '    var template: BoardTemplate\n    var threadColor: BoardThreadColor\n    var mapImage: UIImage')
replace(models, '        template: BoardTemplate = .ribbon,\n        mapImage: UIImage,', '        template: BoardTemplate = .ribbon,\n        threadColor: BoardThreadColor = .vermilion,\n        mapImage: UIImage,')
replace(models, '        self.template = template\n        self.mapImage = mapImage', '        self.template = template\n        self.threadColor = threadColor\n        self.mapImage = mapImage')
replace(models, '            template: template,\n            mapImage: mapImage,', '            template: template,\n            threadColor: threadColor,\n            mapImage: mapImage,')
replace(models, '''struct BoardArchivePayload: Codable {
    let date: Date
    let title: String
    let places: [BoardPlace]
    let template: BoardTemplate
}''', '''struct BoardArchivePayload: Codable {
    let date: Date
    let title: String
    let places: [BoardPlace]
    let template: BoardTemplate
    let threadColor: BoardThreadColor?

    init(date: Date, title: String, places: [BoardPlace], template: BoardTemplate, threadColor: BoardThreadColor? = nil) {
        self.date = date
        self.title = title
        self.places = places
        self.template = template
        self.threadColor = threadColor
    }
}''')

views = 'MapRibbon/Views/BoardViews.swift'
replace(views, '    @State private var showingTemplatePicker = false\n    @State private var showingAddMenu = false', '    @State private var showingTemplatePicker = false\n    @State private var showingThreadColorPicker = false\n    @State private var showingAddMenu = false')
replace(views, '''                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("템플릿 변경", systemImage: "square.stack.3d.up")
                    }

                    Divider()''', '''                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("템플릿 변경", systemImage: "square.stack.3d.up")
                    }
                    Button {
                        showingThreadColorPicker = true
                    } label: {
                        Label("실 색상", systemImage: "paintpalette.fill")
                    }

                    Divider()''')
replace(views, '''        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerSheet(draft: draft)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExport) {''', '''        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerSheet(draft: draft)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingThreadColorPicker) {
            ThreadColorPickerSheet(draft: draft)
                .presentationDetents([.height(270)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExport) {''')
replace(views, '            Button("장소 편집") { showingPlaces = true }\n            Button("제목 메모 편집") { showingTitleEditor = true }', '            Button("장소 편집") { showingPlaces = true }\n            Button("실 색상 선택") { showingThreadColorPicker = true }\n            Button("제목 메모 편집") { showingTitleEditor = true }')
replace(views, '        .onChange(of: draft.template) { _, _ in hasUnsavedChanges = true }\n        .onChange(of: draft.places) { _, _ in hasUnsavedChanges = true }', '        .onChange(of: draft.template) { _, _ in hasUnsavedChanges = true }\n        .onChange(of: draft.threadColor) { _, _ in hasUnsavedChanges = true }\n        .onChange(of: draft.places) { _, _ in hasUnsavedChanges = true }')
replace(views, '''            BoardEditorToolButton(title: "장소 추가", symbol: "mappin.and.ellipse") {
                showingPlaces = true
            }''', '''            BoardEditorToolButton(title: "실 색상", symbol: "paintpalette.fill") {
                showingThreadColorPicker = true
            }''')
replace(views, 'BoardArchivePayload(date: draft.date, title: draft.title, places: draft.places, template: draft.template)', 'BoardArchivePayload(date: draft.date, title: draft.title, places: draft.places, template: draft.template, threadColor: draft.threadColor)')
replace(views, 'private struct TitleEditorSheet: View {', '''private struct ThreadColorPickerSheet: View {
    @Bindable var draft: BoardDraft
    @Environment(\\.dismiss) private var dismiss

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
                    .accessibilityLabel("실 색상 \\(color.title)")
                    .accessibilityAddTraits(draft.threadColor == color ? .isSelected : [])
                }
            }
            .padding(20).background(MRColor.background)
            .navigationTitle("실 색상").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
        }
    }
}

private struct TitleEditorSheet: View {''')
replace(views, '''            paperMap(in: mapRect)
            routeLayer(anchors: anchors, width: mapRect.width)
            photoCards(places: places, placements: placements, in: mapRect)
            pinLayer(anchors: anchors, width: mapRect.width)''', '''            paperMap(in: mapRect)
            photoCards(places: places, placements: placements, in: mapRect)
            routeLayer(anchors: anchors, width: mapRect.width)
            pinLayer(anchors: anchors, width: mapRect.width)''')
replace(views, '                .scaledToFill()\n                .saturation(0.38)', '                .scaledToFit()\n                .background(Color(hex: 0xE9E2D4))\n                .saturation(0.38)')
replace(views, '            let ropeWidth = max(3.4, width * 0.0072)', '            let ropeWidth = max(2.5, width * 0.0054)\n            let threadColor = Color(hex: model.threadColor.primaryHex)\n            let threadHighlight = Color(hex: model.threadColor.highlightHex)')
replace(views, '''                context.stroke(path, with: .color(.black.opacity(0.22)), style: StrokeStyle(lineWidth: ropeWidth * 1.55, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(Color(hex: 0xA52D24)), style: StrokeStyle(lineWidth: ropeWidth, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(Color(hex: 0xE27867).opacity(0.55)), style: StrokeStyle(lineWidth: max(0.7, ropeWidth * 0.18), lineCap: .round))''', '''                context.stroke(path, with: .color(.black.opacity(0.24)), style: StrokeStyle(lineWidth: ropeWidth * 1.42, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(threadColor), style: StrokeStyle(lineWidth: ropeWidth, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(threadHighlight.opacity(0.62)), style: StrokeStyle(lineWidth: max(0.55, ropeWidth * 0.16), lineCap: .round))''')

service = 'MapRibbon/Services/BoardGenerationService.swift'
replace(service, '        let latitudeDelta = max(0.015, (maxLat - minLat) * 1.55)\n        let longitudeDelta = max(0.015, (maxLon - minLon) * 1.55)', '        let latitudeDelta = max(0.045, (maxLat - minLat) * 2.10)\n        let longitudeDelta = max(0.055, (maxLon - minLon) * 2.10)')

app = 'MapRibbon/App/MapRibbonApp.swift'
for old, new in [
    ('point: CGPoint(x: 0.22, y: 0.28)', 'point: CGPoint(x: 0.16, y: 0.18)'),
    ('point: CGPoint(x: 0.75, y: 0.30)', 'point: CGPoint(x: 0.80, y: 0.24)'),
    ('point: CGPoint(x: 0.28, y: 0.53)', 'point: CGPoint(x: 0.38, y: 0.50)'),
    ('point: CGPoint(x: 0.25, y: 0.75)', 'point: CGPoint(x: 0.18, y: 0.76)'),
    ('point: CGPoint(x: 0.70, y: 0.75)', 'point: CGPoint(x: 0.82, y: 0.84)'),
    ('            template: .ribbon,\n            mapImage: makeMapImage(),', '            template: .ribbon,\n            threadColor: .indigo,\n            mapImage: makeMapImage(),'),
    ('let size = CGSize(width: 900, height: 1_200)', 'let size = CGSize(width: 1_200, height: 1_200)'),
    ('for index in 0..<13 {\n                let x = CGFloat(35 + index * 72)', 'for index in 0..<17 {\n                let x = CGFloat(28 + index * 72)'),
    ('context.move(to: CGPoint(x: 800, y: -30))', 'context.move(to: CGPoint(x: 1_055, y: -30))'),
    ('to: CGPoint(x: 700, y: 1_250),\n                control1: CGPoint(x: 675, y: 330),\n                control2: CGPoint(x: 845, y: 820)', 'to: CGPoint(x: 930, y: 1_250),\n                control1: CGPoint(x: 850, y: 300),\n                control2: CGPoint(x: 1_080, y: 820)'),
    ('let park = UIBezierPath(roundedRect: CGRect(x: 310, y: 760, width: 290, height: 240), cornerRadius: 74)', 'let park = UIBezierPath(roundedRect: CGRect(x: 410, y: 735, width: 360, height: 250), cornerRadius: 78)'),
    ('let x = CGFloat((index * 73) % 900)', 'let x = CGFloat((index * 73) % 1_200)')
]:
    replace(app, old, new)
replace(app, '''                ("경복궁", CGPoint(x: 220, y: 190)),
                ("종로", CGPoint(x: 480, y: 310)),
                ("광장시장", CGPoint(x: 650, y: 440)),
                ("시청", CGPoint(x: 350, y: 640)),
                ("덕수궁", CGPoint(x: 240, y: 855)),
                ("남산", CGPoint(x: 500, y: 980)),
                ("한강", CGPoint(x: 755, y: 660))''', '''                ("서촌", CGPoint(x: 130, y: 170)),
                ("경복궁", CGPoint(x: 265, y: 245)),
                ("종로", CGPoint(x: 520, y: 320)),
                ("광장시장", CGPoint(x: 825, y: 385)),
                ("시청", CGPoint(x: 390, y: 610)),
                ("덕수궁", CGPoint(x: 250, y: 790)),
                ("남산", CGPoint(x: 600, y: 930)),
                ("성수", CGPoint(x: 945, y: 600)),
                ("한강", CGPoint(x: 920, y: 835))''')

tests = 'MapRibbonTests/PhotoClustererTests.swift'
replace(tests, '''    func testStoryLayoutUsesLargerCardsThanPoster() {
        let story = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 9.0 / 16.0)
        let poster = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 3.0 / 4.0)
        XCTAssertGreaterThan(story[0].widthFactor, poster[0].widthFactor)
    }
''', '''    func testStoryLayoutUsesLargerCardsThanPoster() {
        let story = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 9.0 / 16.0)
        let poster = BoardLayoutEngine.cardPlacements(for: 5, aspectRatio: 3.0 / 4.0)
        XCTAssertGreaterThan(story[0].widthFactor, poster[0].widthFactor)
    }

    func testThreadPaletteProvidesDistinctRenderColors() {
        XCTAssertEqual(BoardThreadColor.allCases.count, 6)
        XCTAssertEqual(Set(BoardThreadColor.allCases.map(\\.primaryHex)).count, 6)
        XCTAssertTrue(BoardThreadColor.allCases.allSatisfy { $0.primaryHex != $0.highlightHex })
    }
''')

print('Applied thinner selectable thread, photo overlay, and wider map')
