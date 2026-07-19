from __future__ import annotations

import re
from pathlib import Path


BOARD = Path("MapRibbon/Views/BoardViews.swift")
APP = Path("MapRibbon/App/MapRibbonApp.swift")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError(f"{label}: expected one exact match, found {text.count(old)}")
    return text.replace(old, new, 1)


board = BOARD.read_text(encoding="utf-8")
board = replace_once(
    board,
    '''        let boardRect = CGRect(
            x: size.width * 0.035,
            y: size.height * 0.025,
            width: size.width * 0.93,
            height: size.height * 0.95
        )
        let mapRect = boardRect.insetBy(dx: size.width * 0.035, dy: size.width * 0.035)''',
    '''        let boardRect = CGRect(
            x: size.width * 0.02,
            y: size.height * 0.015,
            width: size.width * 0.96,
            height: size.height * 0.97
        )
        let mapRect = boardRect.insetBy(dx: size.width * 0.025, dy: size.width * 0.025)''',
    "ribbon frame",
)
board = replace_once(board, "            ropeLayer(in: mapRect, scale: 0.205)\n            photoLayer(in: mapRect, scale: 0.205, labeled: true)\n            pinLayer(in: mapRect, scale: 0.205)", "            ropeLayer(in: mapRect, scale: 0.245)\n            photoLayer(in: mapRect, scale: 0.245, labeled: true)\n            pinLayer(in: mapRect, scale: 0.245)", "ribbon card scale")
board = replace_once(board, "            ropeLayer(in: mapRect, scale: 0.21)\n            photoLayer(in: mapRect, scale: 0.21, labeled: true)\n            pinLayer(in: mapRect, scale: 0.21)", "            ropeLayer(in: mapRect, scale: 0.245)\n            photoLayer(in: mapRect, scale: 0.245, labeled: true)\n            pinLayer(in: mapRect, scale: 0.245)", "scrapbook card scale")
board = replace_once(board, "            let thickness = max(6, rect.width * 0.016)", "            let thickness = max(7, rect.width * 0.018)", "rope thickness")
board = replace_once(board, "        let cardHeight = rect.height * scale * 0.98", "        let cardHeight = rect.width * scale * 1.34", "card anchor geometry")
board = replace_once(board, "        let height = size.height * scale * (labeled ? 1.02 : 0.86)", "        let height = width * (labeled ? 1.34 : 1.08)", "photo card ratio")
board = replace_once(board, "                    .frame(width: width * 0.88, height: labeled ? height * 0.64 : height * 0.78)", "                    .frame(width: width * 0.88, height: labeled ? height * 0.68 : height * 0.80)", "photo crop ratio")
board = replace_once(
    board,
    '''        let all = [
            CGPoint(x: 0.25, y: 0.30), CGPoint(x: 0.74, y: 0.36),
            CGPoint(x: 0.24, y: 0.53), CGPoint(x: 0.28, y: 0.75),
            CGPoint(x: 0.73, y: 0.72), CGPoint(x: 0.22, y: 0.86),
            CGPoint(x: 0.52, y: 0.47), CGPoint(x: 0.51, y: 0.80)
        ]''',
    '''        let all = [
            CGPoint(x: 0.25, y: 0.31), CGPoint(x: 0.74, y: 0.40),
            CGPoint(x: 0.24, y: 0.56), CGPoint(x: 0.30, y: 0.77),
            CGPoint(x: 0.73, y: 0.73), CGPoint(x: 0.22, y: 0.88),
            CGPoint(x: 0.52, y: 0.49), CGPoint(x: 0.52, y: 0.82)
        ]''',
    "card positions",
)
BOARD.write_text(board, encoding="utf-8")

app = APP.read_text(encoding="utf-8")
pattern = r'''    private static func makePhoto\(symbol: String, title: String, colors: \[UIColor\]\) -> UIImage \{.*?\n    \}\n\}'''
replacement = r'''    private static func makePhoto(symbol: String, title: String, colors: [UIColor]) -> UIImage {
        let size = CGSize(width: 700, height: 520)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map(\.cgColor) as CFArray,
                locations: [0, 1]
            )
            if let gradient {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            context.saveGState()
            if symbol == "building.columns.fill" {
                UIColor(red: 0.30, green: 0.55, blue: 0.24, alpha: 0.92).setFill()
                context.fill(CGRect(x: 0, y: 365, width: size.width, height: 155))
                drawSymbol(symbol, pointSize: 250, center: CGPoint(x: 350, y: 300), color: .white.withAlphaComponent(0.90))
            } else if symbol == "storefront.fill" {
                UIColor(red: 0.12, green: 0.09, blue: 0.07, alpha: 0.60).setFill()
                context.fill(CGRect(x: 55, y: 105, width: 590, height: 350))
                for index in 0..<8 {
                    let bulb = UIColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 0.92)
                    bulb.setFill()
                    context.fillEllipse(in: CGRect(x: 95 + index * 72, y: 130 + (index % 2) * 18, width: 18, height: 18))
                }
                drawSymbol(symbol, pointSize: 210, center: CGPoint(x: 350, y: 325), color: .white.withAlphaComponent(0.86))
            } else if symbol == "cup.and.saucer.fill" {
                UIColor(red: 0.38, green: 0.25, blue: 0.17, alpha: 0.88).setFill()
                context.fill(CGRect(x: 0, y: 310, width: size.width, height: 210))
                drawSymbol(symbol, pointSize: 220, center: CGPoint(x: 355, y: 302), color: UIColor(red: 0.96, green: 0.91, blue: 0.82, alpha: 0.94))
            } else if symbol == "tree.fill" {
                UIColor(red: 0.68, green: 0.57, blue: 0.40, alpha: 0.82).setFill()
                context.fill(CGRect(x: 0, y: 385, width: size.width, height: 135))
                for index in 0..<5 {
                    drawSymbol(symbol, pointSize: CGFloat(145 + index * 8), center: CGPoint(x: 95 + index * 130, y: 300 + CGFloat(index % 2) * 24), color: UIColor(red: 0.16, green: 0.34, blue: 0.18, alpha: 0.88))
                }
            } else {
                UIColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 0.78).setFill()
                context.fill(CGRect(x: 0, y: 330, width: size.width, height: 190))
                for index in 0..<12 {
                    let width = CGFloat(28 + (index % 3) * 10)
                    let height = CGFloat(70 + (index % 5) * 24)
                    UIColor.black.withAlphaComponent(0.55).setFill()
                    context.fill(CGRect(x: CGFloat(15 + index * 58), y: 420 - height, width: width, height: height))
                    UIColor(red: 1, green: 0.78, blue: 0.36, alpha: 0.86).setFill()
                    context.fill(CGRect(x: CGFloat(22 + index * 58), y: 390 - height, width: 6, height: 6))
                }
                drawSymbol(symbol, pointSize: 150, center: CGPoint(x: 515, y: 170), color: .white.withAlphaComponent(0.90))
            }
            context.restoreGState()

            UIColor.white.withAlphaComponent(0.06).setFill()
            for index in 0..<120 {
                let x = CGFloat((index * 83) % 700)
                let y = CGFloat((index * 137) % 520)
                context.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
            }

            let vignette = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.22).cgColor] as CFArray,
                locations: [0.45, 1]
            )
            if let vignette {
                context.drawRadialGradient(
                    vignette,
                    startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 80,
                    endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    endRadius: 470,
                    options: []
                )
            }
        }
    }

    private static func drawSymbol(_ name: String, pointSize: CGFloat, center: CGPoint, color: UIColor) {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        image.draw(at: CGPoint(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2))
    }
}'''
app, count = re.subn(pattern, replacement, app, count=1, flags=re.DOTALL)
if count != 1:
    raise RuntimeError(f"fixture photo renderer: expected one match, found {count}")
APP.write_text(app, encoding="utf-8")
