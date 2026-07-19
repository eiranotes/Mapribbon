from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageFilter


SWIFT_PATH = Path("MapRibbon/Views/BoardViews.swift")
ROPE_PATH = Path(
    "MapRibbon/Resources/Assets.xcassets/RouteRopeRed.imageset/RouteRopeRed.png"
)


def replace_block(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    return updated


def patch_coordinate_layers() -> None:
    text = SWIFT_PATH.read_text(encoding="utf-8")

    rope_layer = '''    @ViewBuilder private func ropeLayer(_ size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let points = routePoints(in: canvasSize)
            let thickness = max(5, canvasSize.width * 0.014)
            let resolvedRope = context.resolve(Image("RouteRopeRed"))
            let tileWidth = thickness * 2.45

            for segment in routeSegments(from: points) {
                let deltaX = segment.end.x - segment.start.x
                let deltaY = segment.end.y - segment.start.y
                let length = max(sqrt(deltaX * deltaX + deltaY * deltaY), thickness)
                let angle = Angle(radians: Double(atan2(deltaY, deltaX)))
                let midpoint = CGPoint(
                    x: (segment.start.x + segment.end.x) * 0.5,
                    y: (segment.start.y + segment.end.y) * 0.5
                )

                context.drawLayer { layer in
                    layer.translateBy(x: midpoint.x, y: midpoint.y)
                    layer.rotate(by: angle)
                    layer.addFilter(
                        .shadow(
                            color: .black.opacity(0.18),
                            radius: thickness * 0.30,
                            x: 0,
                            y: thickness * 0.18
                        )
                    )

                    var tileOrigin = -length * 0.5
                    while tileOrigin < length * 0.5 {
                        let remaining = length * 0.5 - tileOrigin
                        let width = min(tileWidth, remaining)
                        layer.draw(
                            resolvedRope,
                            in: CGRect(
                                x: tileOrigin,
                                y: -thickness * 0.5,
                                width: width,
                                height: thickness
                            )
                        )
                        tileOrigin += tileWidth * 0.90
                    }
                }
            }
        }
    }

    @ViewBuilder private func pinLayer'''
    text = replace_block(
        text,
        r"    @ViewBuilder private func ropeLayer\(_ size: CGSize\) -> some View \{.*?\n    \}\n\n    @ViewBuilder private func pinLayer",
        rope_layer,
        "rope layer",
    )

    pin_layer = '''    @ViewBuilder private func pinLayer(_ size: CGSize) -> some View {
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

        ForEach(points.indices, id: \.self) { index in
            Image(pinAssets[index % pinAssets.count])
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: pinWidth, height: pinHeight)
                .shadow(
                    color: .black.opacity(0.22),
                    radius: pinWidth * 0.09,
                    y: pinWidth * 0.07
                )
                .position(
                    x: points[index].x,
                    y: points[index].y - pinHeight * 0.36
                )
        }
    }

    private func routePoints'''
    text = replace_block(
        text,
        r"    @ViewBuilder private func pinLayer\(_ size: CGSize\) -> some View \{.*?\n    \}\n\n    private func routePoints",
        pin_layer,
        "pin layer",
    )

    SWIFT_PATH.write_text(text, encoding="utf-8")


def smoothstep(value: float, start: float, end: float) -> float:
    if value <= start:
        return 0.0
    if value >= end:
        return 1.0
    t = (value - start) / (end - start)
    return t * t * (3.0 - 2.0 * t)


def clean_rope_asset() -> None:
    source = Image.open(ROPE_PATH).convert("RGBA")
    output = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    output_pixels = output.load()

    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, alpha = source_pixels[x, y]
            if alpha == 0:
                continue

            dominant_other = max(green, blue)
            red_delta = red - dominant_other
            red_ratio = red / max(1.0, green + blue)

            dominance = smoothstep(red_delta, 3.0, 25.0)
            ratio = smoothstep(red_ratio, 0.72, 1.38)
            keep = max(dominance, ratio)

            if red < 14 or keep <= 0.02:
                continue

            cleaned_alpha = int(alpha * min(1.0, 0.10 + keep * 0.90))
            if cleaned_alpha < 8:
                continue

            luminance = red * 0.42 + green * 0.36 + blue * 0.22
            cleaned_red = max(18, min(255, int(luminance * 1.72 + 18)))
            cleaned_green = max(2, min(105, int(luminance * 0.34)))
            cleaned_blue = max(2, min(82, int(luminance * 0.25)))
            output_pixels[x, y] = (
                cleaned_red,
                cleaned_green,
                cleaned_blue,
                cleaned_alpha,
            )

    alpha = output.getchannel("A")
    alpha = alpha.filter(ImageFilter.MedianFilter(3))
    alpha = alpha.point(lambda value: 0 if value < 22 else value)
    output.putalpha(alpha)

    bounding_box = output.getbbox()
    if bounding_box is None:
        raise RuntimeError("rope chroma cleanup removed the complete asset")

    output = output.crop(bounding_box)

    pixels = output.load()
    for x in range(output.width):
        pixels[x, 0] = (0, 0, 0, 0)
        pixels[x, output.height - 1] = (0, 0, 0, 0)

    output.save(ROPE_PATH, optimize=True)


def main() -> None:
    patch_coordinate_layers()
    clean_rope_asset()


if __name__ == "__main__":
    main()
