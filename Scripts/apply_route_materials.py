#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOARD_VIEWS = ROOT / "MapRibbon/Views/BoardViews.swift"
ASSET_CATALOG = ROOT / "MapRibbon/Resources/Assets.xcassets"
MATERIAL_SOURCE = ROOT / "Scripts/RouteMaterials"

HELPER_INSERT = '\nprivate struct BoardRouteSegment: Identifiable {\n    let id: Int\n    let start: CGPoint\n    let end: CGPoint\n}\n\nprivate struct TexturedRopeSegment: View {\n    let start: CGPoint\n    let end: CGPoint\n    let thickness: CGFloat\n\n    var body: some View {\n        let deltaX = end.x - start.x\n        let deltaY = end.y - start.y\n        let length = max(sqrt(deltaX * deltaX + deltaY * deltaY), thickness)\n        let angle = Angle(radians: Double(atan2(deltaY, deltaX)))\n\n        Image("RouteRopeRed")\n            .resizable(\n                capInsets: EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10),\n                resizingMode: .tile\n            )\n            .interpolation(.high)\n            .frame(width: length + thickness * 0.7, height: thickness)\n            .rotationEffect(angle)\n            .position(\n                x: (start.x + end.x) * 0.5,\n                y: (start.y + end.y) * 0.5\n            )\n            .shadow(color: .black.opacity(0.22), radius: thickness * 0.28, y: thickness * 0.18)\n    }\n}\n\n'
OLD_ROUTE = '    @ViewBuilder private func routeLayer(_ size: CGSize) -> some View {\n        Canvas { context, canvas in\n            let places = model.visiblePlaces\n            guard let first = places.first, let firstPoint = model.normalizedPoints[first.id] else { return }\n            var path = Path()\n            path.move(to: CGPoint(x: firstPoint.x * canvas.width, y: firstPoint.y * canvas.height))\n            for place in places.dropFirst() {\n                guard let point = model.normalizedPoints[place.id] else { continue }\n                path.addLine(to: CGPoint(x: point.x * canvas.width, y: point.y * canvas.height))\n            }\n            context.stroke(path, with: .color(MRColor.accent), style: StrokeStyle(lineWidth: max(2, canvas.width * 0.007), lineCap: .round, lineJoin: .round, dash: [canvas.width * 0.02, canvas.width * 0.014]))\n        }\n\n        ForEach(Array(model.visiblePlaces.enumerated()), id: \\.element.id) { index, place in\n            if let point = model.normalizedPoints[place.id] {\n                ZStack {\n                    Circle().fill(MRColor.accent)\n                    Text("\\(index + 1)").font(.system(size: max(8, size.width * 0.025), weight: .bold)).foregroundStyle(.white)\n                }\n                .frame(width: size.width * 0.055, height: size.width * 0.055)\n                .position(x: point.x * size.width, y: point.y * size.height)\n            }\n        }\n    }\n'
NEW_ROUTE = '    @ViewBuilder private func ropeLayer(_ size: CGSize) -> some View {\n        let points = routePoints(in: size)\n        let thickness = max(5, size.width * 0.018)\n\n        ZStack {\n            ForEach(routeSegments(from: points)) { segment in\n                TexturedRopeSegment(\n                    start: segment.start,\n                    end: segment.end,\n                    thickness: thickness\n                )\n            }\n        }\n        .frame(width: size.width, height: size.height)\n    }\n\n    @ViewBuilder private func pinLayer(_ size: CGSize) -> some View {\n        let points = routePoints(in: size)\n        let pinWidth = max(28, size.width * 0.082)\n        let pinHeight = pinWidth * 1.60\n        let pinAssets = [\n            "RoutePinBlue",\n            "RoutePinTeal",\n            "RoutePinYellow",\n            "RoutePinCream",\n            "RoutePinRed",\n            "RoutePinGreen"\n        ]\n\n        ZStack {\n            ForEach(points.indices, id: \\.self) { index in\n                Image(pinAssets[index % pinAssets.count])\n                    .resizable()\n                    .interpolation(.high)\n                    .scaledToFit()\n                    .frame(width: pinWidth, height: pinHeight)\n                    .shadow(color: .black.opacity(0.25), radius: pinWidth * 0.10, y: pinWidth * 0.08)\n                    .position(\n                        x: points[index].x,\n                        y: points[index].y + pinHeight * 0.29\n                    )\n            }\n        }\n        .frame(width: size.width, height: size.height)\n    }\n\n    private func routePoints(in size: CGSize) -> [CGPoint] {\n        switch model.template {\n        case .ribbon:\n            return cardAnchorPoints(count: model.visiblePlaces.count, size: size, scale: 0.19)\n        case .scrapbook:\n            return cardAnchorPoints(count: model.visiblePlaces.count, size: size, scale: 0.20)\n        case .editorial, .postcard:\n            return model.visiblePlaces.compactMap { place in\n                guard let point = model.normalizedPoints[place.id] else { return nil }\n                return CGPoint(x: point.x * size.width, y: point.y * size.height)\n            }\n        }\n    }\n\n    private func cardAnchorPoints(count: Int, size: CGSize, scale: CGFloat) -> [CGPoint] {\n        let positions = cardPositions(count: count)\n        let cardHeight = size.height * scale * 0.86\n\n        return positions.map { position in\n            CGPoint(\n                x: position.x * size.width,\n                y: position.y * size.height - cardHeight * 0.40\n            )\n        }\n    }\n\n    private func routeSegments(from points: [CGPoint]) -> [BoardRouteSegment] {\n        guard points.count > 1 else { return [] }\n\n        return (0..<(points.count - 1)).map { index in\n            BoardRouteSegment(id: index, start: points[index], end: points[index + 1])\n        }\n    }\n'

def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    return source.replace(old, new, 1)

def write_assets() -> None:
    for encoded in sorted(MATERIAL_SOURCE.glob('*.png.b64')):
        filename = encoded.name.removesuffix('.b64')
        asset_name = filename.removesuffix('.png')
        imageset = ASSET_CATALOG / f'{asset_name}.imageset'
        imageset.mkdir(parents=True, exist_ok=True)
        (imageset / filename).write_bytes(base64.b64decode(encoded.read_text(encoding='ascii')))
        contents = {
            'images': [
                {'filename': filename, 'idiom': 'universal', 'scale': '1x'},
                {'idiom': 'universal', 'scale': '2x'},
                {'idiom': 'universal', 'scale': '3x'},
            ],
            'info': {'author': 'xcode', 'version': 1},
        }
        (imageset / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n', encoding='utf-8')

def patch_board_views() -> None:
    source = BOARD_VIEWS.read_text(encoding='utf-8')
    source = replace_once(
        source,
        'extension Binding where Value == String {\n',
        HELPER_INSERT + 'extension Binding where Value == String {\n',
        'route helper insertion',
    )
    source = replace_once(
        source,
        '            routeLayer(size)\n            photoLayer(size, scale: 0.19)\n',
        '            ropeLayer(size)\n            photoLayer(size, scale: 0.19)\n            pinLayer(size)\n',
        'ribbon layer order',
    )
    source = replace_once(
        source,
        '                    routeLayer(CGSize(width: size.width, height: size.height * 0.68))\n',
        '                    ropeLayer(CGSize(width: size.width, height: size.height * 0.68))\n                    pinLayer(CGSize(width: size.width, height: size.height * 0.68))\n',
        'editorial route layer',
    )
    source = replace_once(
        source,
        '            routeLayer(size)\n                .padding(size.width * 0.07)\n            photoLayer(size, scale: 0.17)\n',
        '            ropeLayer(size)\n            photoLayer(size, scale: 0.17)\n            pinLayer(size)\n',
        'postcard layer order',
    )
    source = replace_once(
        source,
        '            routeLayer(size)\n            photoLayer(size, scale: 0.20)\n',
        '            ropeLayer(size)\n            photoLayer(size, scale: 0.20)\n            pinLayer(size)\n',
        'scrapbook layer order',
    )
    source = replace_once(source, OLD_ROUTE, NEW_ROUTE, 'route renderer')
    BOARD_VIEWS.write_text(source, encoding='utf-8')

def main() -> None:
    write_assets()
    patch_board_views()
    print('Applied textured rope and pushpin board materials.')

if __name__ == '__main__':
    main()
