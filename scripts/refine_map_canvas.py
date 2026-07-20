from pathlib import Path

ROOT = Path('.')

def replace(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'missing pattern in {path}: {old[:100]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')

views = 'MapRibbon/Views/BoardViews.swift'
replace(views, '    @State private var showingThreadColorPicker = false', '    @State private var showingThreadColorPicker = ProcessInfo.processInfo.arguments.contains("--screenshot-thread-colors")')
replace(views, '''                .scaledToFit()
                .background(Color(hex: 0xE9E2D4))
                .saturation(0.38)''', '''                .scaledToFill()
                .saturation(0.38)''')

app = 'MapRibbon/App/MapRibbonApp.swift'
replace(app, '''                } else if launchArguments.contains("--screenshot-board-editor") {
                    BoardEditorScreenshotFixtureView()''', '''                } else if launchArguments.contains("--screenshot-thread-colors") {
                    BoardEditorScreenshotFixtureView()
                } else if launchArguments.contains("--screenshot-board-editor") {
                    BoardEditorScreenshotFixtureView()''')
replace(app, 'let size = CGSize(width: 1_200, height: 1_200)', 'let size = CGSize(width: 1_200, height: 1_600)')
replace(app, 'for index in 0..<18 {\n                let y = CGFloat(55 + index * 66)', 'for index in 0..<24 {\n                let y = CGFloat(48 + index * 66)')
replace(app, '''                to: CGPoint(x: 930, y: 1_250),
                control1: CGPoint(x: 850, y: 300),
                control2: CGPoint(x: 1_080, y: 820)''', '''                to: CGPoint(x: 930, y: 1_650),
                control1: CGPoint(x: 850, y: 390),
                control2: CGPoint(x: 1_080, y: 1_080)''')
replace(app, 'let park = UIBezierPath(roundedRect: CGRect(x: 410, y: 735, width: 360, height: 250), cornerRadius: 78)', 'let park = UIBezierPath(roundedRect: CGRect(x: 410, y: 1_010, width: 360, height: 280), cornerRadius: 82)')
replace(app, '''                ("서촌", CGPoint(x: 130, y: 170)),
                ("경복궁", CGPoint(x: 265, y: 245)),
                ("종로", CGPoint(x: 520, y: 320)),
                ("광장시장", CGPoint(x: 825, y: 385)),
                ("시청", CGPoint(x: 390, y: 610)),
                ("덕수궁", CGPoint(x: 250, y: 790)),
                ("남산", CGPoint(x: 600, y: 930)),
                ("성수", CGPoint(x: 945, y: 600)),
                ("한강", CGPoint(x: 920, y: 835))''', '''                ("서촌", CGPoint(x: 130, y: 185)),
                ("경복궁", CGPoint(x: 265, y: 295)),
                ("종로", CGPoint(x: 520, y: 430)),
                ("광장시장", CGPoint(x: 825, y: 535)),
                ("시청", CGPoint(x: 390, y: 785)),
                ("덕수궁", CGPoint(x: 250, y: 980)),
                ("성수", CGPoint(x: 945, y: 835)),
                ("남산", CGPoint(x: 600, y: 1_165)),
                ("한강", CGPoint(x: 920, y: 1_285))''')
replace(app, 'let y = CGFloat((index * 127) % 1_200)', 'let y = CGFloat((index * 127) % 1_600)')

ci = '.github/workflows/ios-ci.yml'
replace(ci, '          capture --screenshot-board-editor board-editor\n', '          capture --screenshot-board-editor board-editor\n          capture --screenshot-thread-colors thread-colors\n')

print('Refined full-height wide map canvas and thread color screenshot state')
# Trigger after the workflow exists on the branch.
