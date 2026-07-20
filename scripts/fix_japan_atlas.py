from pathlib import Path
import re

path = Path("MapRibbon/Views/AtlasSettingsViews.swift")
source = path.read_text(encoding="utf-8")

source = re.sub(
    r'''    static let all: \[JapanAtlasRegion\] = \[.*?    \]\n\}''',
    '''    static let all: [JapanAtlasRegion] = [
        .init(key: "일본:홋카이도", shortName: "홋카이도", normalizedPoint: CGPoint(x: 0.75, y: 0.13)),
        .init(key: "일본:도호쿠", shortName: "도호쿠", normalizedPoint: CGPoint(x: 0.63, y: 0.30)),
        .init(key: "일본:간토", shortName: "간토", normalizedPoint: CGPoint(x: 0.61, y: 0.49)),
        .init(key: "일본:주부", shortName: "주부", normalizedPoint: CGPoint(x: 0.49, y: 0.53)),
        .init(key: "일본:간사이", shortName: "간사이", normalizedPoint: CGPoint(x: 0.38, y: 0.61)),
        .init(key: "일본:주고쿠", shortName: "주고쿠", normalizedPoint: CGPoint(x: 0.26, y: 0.68)),
        .init(key: "일본:시코쿠", shortName: "시코쿠", normalizedPoint: CGPoint(x: 0.36, y: 0.73)),
        .init(key: "일본:규슈", shortName: "규슈", normalizedPoint: CGPoint(x: 0.16, y: 0.82)),
    ]
}''',
    source,
    count=1,
    flags=re.S,
)

new_path = '''    private func japanPath(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()

        // Hokkaido
        path.move(to: p(0.68, 0.05))
        path.addCurve(to: p(0.88, 0.06), control1: p(0.75, 0.01), control2: p(0.84, 0.02))
        path.addCurve(to: p(0.91, 0.15), control1: p(0.92, 0.09), control2: p(0.92, 0.12))
        path.addCurve(to: p(0.76, 0.21), control1: p(0.87, 0.19), control2: p(0.81, 0.22))
        path.addCurve(to: p(0.65, 0.13), control1: p(0.70, 0.20), control2: p(0.65, 0.17))
        path.addCurve(to: p(0.68, 0.05), control1: p(0.63, 0.09), control2: p(0.65, 0.07))
        path.closeSubpath()

        // Honshu: one continuous, narrow island chain from Tohoku to Chugoku.
        path.move(to: p(0.62, 0.20))
        path.addCurve(to: p(0.70, 0.34), control1: p(0.68, 0.23), control2: p(0.71, 0.28))
        path.addCurve(to: p(0.67, 0.47), control1: p(0.71, 0.40), control2: p(0.70, 0.44))
        path.addCurve(to: p(0.56, 0.56), control1: p(0.64, 0.51), control2: p(0.60, 0.54))
        path.addCurve(to: p(0.42, 0.64), control1: p(0.51, 0.59), control2: p(0.47, 0.62))
        path.addCurve(to: p(0.23, 0.71), control1: p(0.35, 0.68), control2: p(0.28, 0.71))
        path.addCurve(to: p(0.18, 0.67), control1: p(0.20, 0.71), control2: p(0.18, 0.69))
        path.addCurve(to: p(0.34, 0.61), control1: p(0.23, 0.64), control2: p(0.29, 0.63))
        path.addCurve(to: p(0.47, 0.53), control1: p(0.39, 0.58), control2: p(0.43, 0.56))
        path.addCurve(to: p(0.57, 0.43), control1: p(0.51, 0.49), control2: p(0.55, 0.46))
        path.addCurve(to: p(0.58, 0.28), control1: p(0.60, 0.38), control2: p(0.60, 0.33))
        path.addCurve(to: p(0.62, 0.20), control1: p(0.57, 0.24), control2: p(0.59, 0.21))
        path.closeSubpath()

        // Shikoku
        path.move(to: p(0.30, 0.70))
        path.addCurve(to: p(0.44, 0.70), control1: p(0.35, 0.67), control2: p(0.41, 0.68))
        path.addCurve(to: p(0.43, 0.76), control1: p(0.46, 0.73), control2: p(0.45, 0.75))
        path.addCurve(to: p(0.31, 0.77), control1: p(0.38, 0.78), control2: p(0.34, 0.78))
        path.addCurve(to: p(0.30, 0.70), control1: p(0.29, 0.75), control2: p(0.28, 0.72))
        path.closeSubpath()

        // Kyushu
        path.move(to: p(0.12, 0.73))
        path.addCurve(to: p(0.23, 0.76), control1: p(0.17, 0.71), control2: p(0.21, 0.73))
        path.addCurve(to: p(0.22, 0.88), control1: p(0.26, 0.81), control2: p(0.25, 0.85))
        path.addCurve(to: p(0.14, 0.92), control1: p(0.19, 0.91), control2: p(0.16, 0.93))
        path.addCurve(to: p(0.08, 0.84), control1: p(0.10, 0.90), control2: p(0.08, 0.87))
        path.addCurve(to: p(0.12, 0.73), control1: p(0.07, 0.79), control2: p(0.09, 0.75))
        path.closeSubpath()

        // Okinawa marker island
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.04,
            y: rect.minY + rect.height * 0.94,
            width: rect.width * 0.055,
            height: rect.height * 0.025
        ))
        return path
    }'''

source, count = re.subn(
    r'''    private func japanPath\(in rect: CGRect\) -> Path \{.*?\n    \}''',
    lambda _: new_path,
    source,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError(f"Expected one japanPath replacement, got {count}")

path.write_text(source, encoding="utf-8")
Path("scripts/fix_japan_atlas.py").unlink()
