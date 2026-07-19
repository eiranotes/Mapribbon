from __future__ import annotations

import re
from pathlib import Path

from PIL import Image


SOURCE = Path("MapRibbon/Views/BoardViews.swift")
ASSET_ROOT = Path("MapRibbon/Resources/Assets.xcassets")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return updated


def patch_swift() -> None:
    text = SOURCE.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "capInsets: EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10),",
        "capInsets: EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14),",
        "rope cap insets",
    )
    text = replace_once(
        text,
        ".frame(width: length + thickness * 0.7, height: thickness)",
        ".frame(width: length + thickness * 0.45, height: thickness)",
        "rope frame",
    )
    text = replace_once(
        text,
        ".shadow(color: .black.opacity(0.22), radius: thickness * 0.28, y: thickness * 0.18)",
        ".shadow(color: .black.opacity(0.18), radius: thickness * 0.34, y: thickness * 0.20)",
        "rope shadow",
    )

    rope_block = '''    @ViewBuilder private func ropeLayer(_ size: CGSize) -> some View {
        let points = routePoints(in: size)
        let thickness = max(7, size.width * 0.024)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: size.width, height: size.height)

            ForEach(routeSegments(from: points)) { segment in
                TexturedRopeSegment(
                    start: segment.start,
                    end: segment.end,
                    thickness: thickness
                )
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder private func pinLayer'''
    text = sub_once(
        text,
        r"    @ViewBuilder private func ropeLayer\(_ size: CGSize\) -> some View \{.*?\n    \}\n\n    @ViewBuilder private func pinLayer",
        rope_block,
        "rope coordinate layer",
    )

    pin_block = '''    @ViewBuilder private func pinLayer(_ size: CGSize) -> some View {
        let points = routePoints(in: size)
        let pinWidth = max(28, size.width * 0.078)
        let pinHeight = pinWidth * 1.60
        let pinAssets = [
            "RoutePinBlue",
            "RoutePinTeal",
            "RoutePinYellow",
            "RoutePinCream",
            "RoutePinRed",
            "RoutePinGreen"
        ]

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: size.width, height: size.height)

            ForEach(points.indices, id: \.self) { index in
                Image(pinAssets[index % pinAssets.count])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: pinWidth, height: pinHeight)
                    .shadow(color: .black.opacity(0.22), radius: pinWidth * 0.09, y: pinWidth * 0.07)
                    .position(
                        x: points[index].x,
                        y: points[index].y - pinHeight * 0.36
                    )
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func routePoints'''
    text = sub_once(
        text,
        r"    @ViewBuilder private func pinLayer\(_ size: CGSize\) -> some View \{.*?\n    \}\n\n    private func routePoints",
        pin_block,
        "pin coordinate layer",
    )

    anchor_block = '''    private func cardAnchorPoints(count: Int, size: CGSize, scale: CGFloat) -> [CGPoint] {
        let positions = cardPositions(count: count)
        let cardHeight = size.height * scale * 0.86
        let topInset = cardHeight * 0.40

        return positions.enumerated().map { index, position in
            let center = CGPoint(
                x: position.x * size.width,
                y: position.y * size.height
            )
            let angle = cardRotationDegrees(for: index) * Double.pi / 180
            return CGPoint(
                x: center.x + CGFloat(sin(angle)) * topInset,
                y: center.y - CGFloat(cos(angle)) * topInset
            )
        }
    }

    private func cardRotationDegrees(for index: Int) -> Double {
        let values: [Double] = [-4, 3, -2, 4, -3, 2, -2, 3]
        return values[index % values.count]
    }

    private func routeSegments'''
    text = sub_once(
        text,
        r"    private func cardAnchorPoints\(count: Int, size: CGSize, scale: CGFloat\) -> \[CGPoint\] \{.*?\n    \}\n\n    private func routeSegments",
        anchor_block,
        "rotated card anchors",
    )

    text = replace_once(
        text,
        ".rotationEffect(.degrees([ -5, 4, -2, 6, -4, 3, -3, 5 ][index % 8]))",
        ".rotationEffect(.degrees(cardRotationDegrees(for: index)))",
        "card rotation source",
    )

    text = replace_once(
        text,
        '''        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.width * 0.065)
        .padding(.top, size.height * 0.05)''',
        '''        .padding(.horizontal, size.width * 0.065)
        .padding(.top, size.height * 0.05)
        .frame(width: size.width, height: size.height, alignment: .topLeading)''',
        "header top alignment",
    )

    text = sub_once(
        text,
        r"        let all = \[\n            CGPoint\(x: 0\.22, y: 0\.29\), CGPoint\(x: 0\.76, y: 0\.26\),\n            CGPoint\(x: 0\.69, y: 0\.52\), CGPoint\(x: 0\.28, y: 0\.62\),\n            CGPoint\(x: 0\.72, y: 0\.76\), CGPoint\(x: 0\.22, y: 0\.82\),\n            CGPoint\(x: 0\.49, y: 0\.40\), CGPoint\(x: 0\.50, y: 0\.70\)\n        \]",
        '''        let all = [
            CGPoint(x: 0.24, y: 0.30), CGPoint(x: 0.74, y: 0.34),
            CGPoint(x: 0.25, y: 0.52), CGPoint(x: 0.29, y: 0.71),
            CGPoint(x: 0.72, y: 0.73), CGPoint(x: 0.22, y: 0.84),
            CGPoint(x: 0.50, y: 0.43), CGPoint(x: 0.50, y: 0.68)
        ]''',
        "reference card positions",
    )

    SOURCE.write_text(text, encoding="utf-8")


def clean_green(image: Image.Image, *, red_asset: bool = False) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            green_score = g - max(r, b)
            if green_score > 12 and g > 45:
                fade = max(0.0, min(1.0, (green_score - 8) / 55.0))
                a = int(a * (1.0 - fade))
            if a < 8:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if g > max(r, b):
                g = int(max(r, b) * 0.82)
            if red_asset:
                g = min(g, int(r * 0.52 + 10))
                b = min(b, int(r * 0.34 + 8))
            pixels[x, y] = (r, g, b, a)
    return image


def refine_rope() -> None:
    path = ASSET_ROOT / "RouteRopeRed.imageset" / "RouteRopeRed.png"
    rope = clean_green(Image.open(path), red_asset=True)

    if rope.width <= 120:
        alpha = rope.getchannel("A")
        bbox = alpha.point(lambda value: 255 if value >= 18 else 0).getbbox()
        if bbox:
            _, y0, _, y1 = bbox
            rope = rope.crop((0, max(0, y0 - 1), rope.width, min(rope.height, y1 + 1)))

        pixels = rope.load()
        for x in range(rope.width):
            pixels[x, 0] = (0, 0, 0, 0)
            pixels[x, rope.height - 1] = (0, 0, 0, 0)

        x0 = round(rope.width * 0.26)
        x1 = round(rope.width * 0.71)
        if x1 - x0 >= 30:
            rope = rope.crop((x0, 0, x1, rope.height))
        rope = rope.resize((rope.width * 3, rope.height * 3), Image.Resampling.LANCZOS)

        width = rope.width
        blend = min(16, max(4, width // 10))
        pixels = rope.load()
        for i in range(blend):
            strength = 1.0 - (i / max(1, blend - 1)) * 0.75
            right_x = width - blend + i
            for y in range(rope.height):
                left = pixels[i, y]
                right = pixels[right_x, y]
                average = tuple((left[channel] + right[channel]) // 2 for channel in range(4))
                pixels[i, y] = tuple(
                    round(left[channel] * (1.0 - strength) + average[channel] * strength)
                    for channel in range(4)
                )
                pixels[right_x, y] = tuple(
                    round(right[channel] * (1.0 - strength) + average[channel] * strength)
                    for channel in range(4)
                )

    rope.save(path, optimize=True)


def refine_pins() -> None:
    for path in sorted(ASSET_ROOT.glob("RoutePin*.imageset/RoutePin*.png")):
        pin = clean_green(Image.open(path))
        if pin.width <= 100:
            pin = pin.resize((pin.width * 2, pin.height * 2), Image.Resampling.LANCZOS)
        pin.save(path, optimize=True)


def main() -> None:
    patch_swift()
    refine_rope()
    refine_pins()


if __name__ == "__main__":
    main()
