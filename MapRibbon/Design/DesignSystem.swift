import SwiftUI
import UIKit

// MARK: - "측량 도판(Survey Plate)" 디자인 시스템
// 결과물(보드)이 아날로그 코르크 보드라면, 앱 셸은 그 보드를 만드는 지도 제작실이다.
// 해도지 그리드 · 도판 괘선(neatline) · 좌표 메타 · 루트를 꿰매는 주홍 실이 언어의 전부다.
// 대담함은 스티치 실 하나에만 쓰고 나머지는 조용히 유지한다.

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum MRColor {
    /// 해도지 바탕. 다크 모드는 야간 해도실.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x131B24) : UIColor(hex: 0xEFE9DD)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x1C2631) : UIColor(hex: 0xF8F4E9)
    })
    static let elevatedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x232E3B) : UIColor(hex: 0xFDFBF3)
    })
    static let secondarySurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x2A3541) : UIColor(hex: 0xE5DECE)
    })
    static let primaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xECEFF2) : UIColor(hex: 0x232E38)
    })
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xA8B4BD) : UIColor(hex: 0x5C6B77)
    })
    static let tertiaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x77828C) : UIColor(hex: 0x8A959D)
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x3A4652) : UIColor(hex: 0xC9C0AC)
    })
    /// 도판 괘선 잉크.
    static let frameInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8FA0AE) : UIColor(hex: 0x44525F)
    })
    /// 주홍 실 — 시그니처. 스티치와 핵심 CTA에만 쓴다.
    static let accent = Color(hex: 0xC7402D)
    static let accentPressed = Color(hex: 0xA93524)
    static let accentSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x40261F) : UIColor(hex: 0xF4DFD8)
    })
    /// 놋쇠 — 핀, 스탬프, 이어브로.
    static let brass = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xC29A5B) : UIColor(hex: 0xA5793C)
    })
    static let mapTeal = Color(hex: 0x52808F)
    static let mapTealSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x24333B) : UIColor(hex: 0xDDE8E4)
    })
    static let success = Color(hex: 0x39735A)
    static let warning = Color(hex: 0x9A6728)
    static let paper = Color(hex: 0xF4EFE5)
    static let paperBright = Color(hex: 0xFAF7EF)
    static let ink = Color(hex: 0x1B252B)
    static let cork = Color(hex: 0xA97845)
    static let editorStage = Color(hex: 0x171A1D)
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum MRSpacing {
    static let screen: CGFloat = 20
    static let section: CGFloat = 28
    static let card: CGFloat = 16
    static let compact: CGFloat = 8
    static let tight: CGFloat = 4
}

enum MRRadius {
    static let compact: CGFloat = 6
    static let control: CGFloat = 10
    static let card: CGFloat = 8
    static let sheet: CGFloat = 20
}

// MARK: - 타이포그래피

enum MRType {
    /// 큰 제목: 묵직한 고딕 + 좁은 자간.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy)
    }

    /// 날짜·숫자·좌표: 도판 인쇄 느낌의 세리프.
    static func plate(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// 세리프 이탤릭 이어브로 — 도판 라벨.
struct MREyebrow: View {
    let text: String
    var color: Color = MRColor.brass

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .serif).italic())
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

// MARK: - 해도지 그리드 배경

/// 화면 바탕의 서베이 그리드. 플랫 컬러 대신 종이 위 인쇄된 좌표 격자.
struct MRSurveyGrid: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let minorStep: CGFloat = 26
            let inkColor: Color = colorScheme == .dark ? .white : Color(hex: 0x44525F)
            let minorOpacity = colorScheme == .dark ? 0.040 : 0.055
            let majorOpacity = colorScheme == .dark ? 0.065 : 0.085

            var x: CGFloat = 0
            var columnIndex = 0
            while x <= size.width {
                let major = columnIndex.isMultiple(of: 4)
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    line,
                    with: .color(inkColor.opacity(major ? majorOpacity : minorOpacity)),
                    lineWidth: major ? 0.8 : 0.5
                )
                x += minorStep
                columnIndex += 1
            }

            var y: CGFloat = 0
            var rowIndex = 0
            while y <= size.height {
                let major = rowIndex.isMultiple(of: 4)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    line,
                    with: .color(inkColor.opacity(major ? majorOpacity : minorOpacity)),
                    lineWidth: major ? 0.8 : 0.5
                )
                y += minorStep
                rowIndex += 1
            }

            // 주 격자 교차점의 십자 표시
            let crossStep = minorStep * 4
            let crossHalf: CGFloat = 3.2
            var cx = crossStep
            while cx < size.width {
                var cy = crossStep
                while cy < size.height {
                    var cross = Path()
                    cross.move(to: CGPoint(x: cx - crossHalf, y: cy))
                    cross.addLine(to: CGPoint(x: cx + crossHalf, y: cy))
                    cross.move(to: CGPoint(x: cx, y: cy - crossHalf))
                    cross.addLine(to: CGPoint(x: cx, y: cy + crossHalf))
                    context.stroke(cross, with: .color(inkColor.opacity(colorScheme == .dark ? 0.10 : 0.14)), lineWidth: 0.8)
                    cy += crossStep
                }
                cx += crossStep
            }
        }
        .allowsHitTesting(false)
    }
}

/// 화면 공통 배경: 해도지 + 그리드.
struct MRScreenBackground: View {
    var body: some View {
        ZStack {
            MRColor.background
            MRSurveyGrid()
        }
        .ignoresSafeArea()
    }
}

// MARK: - 도판 괘선(neatline)

/// 이중 괘선 + 변 눈금. 도판(카드)의 정체성.
struct MRPlateFrame: View {
    var cornerRadius: CGFloat = MRRadius.card

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MRColor.frameInk.opacity(0.55), lineWidth: 1.1)
            RoundedRectangle(cornerRadius: max(2, cornerRadius - 4), style: .continuous)
                .inset(by: 4.5)
                .stroke(MRColor.frameInk.opacity(0.30), lineWidth: 0.6)
            Canvas { context, size in
                let tick: CGFloat = 4
                let positions: [CGFloat] = [0.25, 0.5, 0.75]
                for fraction in positions {
                    let x = size.width * fraction
                    let y = size.height * fraction
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: tick))
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x, y: size.height - tick))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: tick, y: y))
                    path.move(to: CGPoint(x: size.width, y: y))
                    path.addLine(to: CGPoint(x: size.width - tick, y: y))
                    context.stroke(path, with: .color(MRColor.frameInk.opacity(0.45)), lineWidth: 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct MRPlateModifier: ViewModifier {
    var padding: CGFloat = MRSpacing.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MRColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.card, style: .continuous))
            .overlay { MRPlateFrame() }
            .shadow(color: Color.black.opacity(0.10), radius: 9, y: 4)
    }
}

struct MRCardModifier: ViewModifier {
    var padding: CGFloat = MRSpacing.card
    var shadow: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MRColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MRRadius.card, style: .continuous)
                    .stroke(MRColor.frameInk.opacity(0.35), lineWidth: 0.8)
            }
            .shadow(color: shadow ? Color.black.opacity(0.08) : .clear, radius: 9, y: 4)
    }
}

struct MRPaperModifier: ViewModifier {
    var padding: CGFloat = MRSpacing.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MRColor.paperBright)
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.compact, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MRRadius.compact, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 0.7)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 7, y: 3)
    }
}

extension View {
    func mrCard(padding: CGFloat = MRSpacing.card, shadow: Bool = false) -> some View {
        modifier(MRCardModifier(padding: padding, shadow: shadow))
    }

    func mrPlate(padding: CGFloat = MRSpacing.card) -> some View {
        modifier(MRPlateModifier(padding: padding))
    }

    func mrPaper(padding: CGFloat = MRSpacing.card) -> some View {
        modifier(MRPaperModifier(padding: padding))
    }
}

// MARK: - 스티치(바느질 실) — 시그니처

/// 두 바늘구멍 사이를 지나는 박음질 실.
struct MRStitch: View {
    var color: Color = MRColor.accent
    var progress: Double = 1

    var body: some View {
        GeometryReader { proxy in
            let y = proxy.size.height / 2
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 8, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width - 8, y: y))
                }
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [6.5, 5]))

                Circle()
                    .fill(color.opacity(0.9))
                    .frame(width: 4.5, height: 4.5)
                    .position(x: 8, y: y)
                Circle()
                    .fill(color.opacity(progress >= 1 ? 0.9 : 0.35))
                    .frame(width: 4.5, height: 4.5)
                    .position(x: proxy.size.width - 8, y: y)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

/// 완만한 곡선을 그리는 실 — 루트 미리보기용.
struct MRRouteThread: View {
    let progress: Double
    var color: Color = MRColor.accent

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let y = proxy.size.height / 2
                path.move(to: CGPoint(x: 6, y: y))
                path.addCurve(
                    to: CGPoint(x: proxy.size.width - 6, y: y),
                    control1: CGPoint(x: proxy.size.width * 0.28, y: y - 9),
                    control2: CGPoint(x: proxy.size.width * 0.68, y: y + 10)
                )
            }
            .trim(from: 0, to: min(1, max(0, progress)))
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 4]))
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}

/// 보드 생성 진행: 다섯 핀 사이를 실이 꿰매며 지나간다.
struct MRRouteProgress: View {
    let progress: Double
    var pinCount: Int = 5

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let midY = proxy.size.height / 2
                let inset: CGFloat = 16
                let usable = width - inset * 2

                ZStack {
                    routePath(width: width, midY: midY, inset: inset)
                        .stroke(MRColor.border.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [3, 5]))

                    routePath(width: width, midY: midY, inset: inset)
                        .trim(from: 0, to: min(1, max(0.015, progress)))
                        .stroke(MRColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 4.5]))

                    ForEach(0..<pinCount, id: \.self) { index in
                        let fraction = Double(index) / Double(max(1, pinCount - 1))
                        let x = inset + usable * CGFloat(fraction)
                        let reached = progress + 0.001 >= fraction
                        ZStack {
                            Circle()
                                .fill(reached ? MRColor.accent : MRColor.surface)
                            Circle()
                                .stroke(reached ? MRColor.accent : MRColor.frameInk.opacity(0.5), lineWidth: 1.4)
                        }
                        .frame(width: reached ? 11 : 9, height: reached ? 11 : 9)
                        .position(x: x, y: waveY(fraction: CGFloat(fraction), midY: midY))
                    }
                }
            }
            .frame(height: 56)

            Text("\(Int(progress * 100))%")
                .font(MRType.plate(40, weight: .bold).monospacedDigit())
                .foregroundStyle(MRColor.primaryText)
        }
        .animation(.easeInOut(duration: 0.22), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("보드 생성 진행률")
        .accessibilityValue("\(Int(progress * 100))퍼센트")
    }

    private func waveY(fraction: CGFloat, midY: CGFloat) -> CGFloat {
        midY + sin(fraction * .pi * 2) * 9
    }

    private func routePath(width: CGFloat, midY: CGFloat, inset: CGFloat) -> Path {
        Path { path in
            let usable = width - inset * 2
            path.move(to: CGPoint(x: inset, y: waveY(fraction: 0, midY: midY)))
            let segments = 24
            for segment in 1...segments {
                let fraction = CGFloat(segment) / CGFloat(segments)
                path.addLine(to: CGPoint(x: inset + usable * fraction, y: waveY(fraction: fraction, midY: midY)))
            }
        }
    }
}

/// 도판을 벽에 고정한 놋쇠 핀.
struct MRPinDot: View {
    var diameter: CGFloat = 11

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xE3CD9C), Color(hex: 0x8A6828)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: diameter * 0.05,
                    endRadius: diameter * 0.75
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.35), radius: 1.6, y: 1.2)
            .accessibilityHidden(true)
    }
}

/// 도판 사이를 세로로 잇는 실.
struct MRVerticalStitch: View {
    var color: Color = MRColor.accent
    var height: CGFloat = 26

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 1.5, y: 3))
            path.addLine(to: CGPoint(x: 1.5, y: height - 3))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [5.5, 4.5]))
        .frame(width: 3, height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - 스탬프

/// 이중 링 도장. 기록 완료·수집 표시에 쓴다.
struct MRStampBadge: View {
    let text: String
    var color: Color = MRColor.brass

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .serif))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.85), lineWidth: 1.3)
                    RoundedRectangle(cornerRadius: 2).inset(by: 2.5).stroke(color.opacity(0.5), lineWidth: 0.7)
                }
            }
            .rotationEffect(.degrees(-4))
            .opacity(0.92)
    }
}

// MARK: - 버튼

struct MRPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.72))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                isEnabled
                ? (configuration.isPressed ? MRColor.accentPressed : MRColor.accent)
                : MRColor.accent.opacity(0.34)
            )
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous))
            .overlay {
                // 안쪽 박음질 — 실로 덧댄 패치.
                RoundedRectangle(cornerRadius: MRRadius.control - 4, style: .continuous)
                    .inset(by: 4)
                    .stroke(.white.opacity(isEnabled ? 0.38 : 0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3.5]))
            }
            .scaleEffect(!reduceMotion && configuration.isPressed && isEnabled ? 0.982 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct MRSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MRColor.primaryText.opacity(isEnabled ? 1 : 0.45))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(MRColor.elevatedSurface.opacity(configuration.isPressed ? 0.74 : 1))
            .clipShape(RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MRRadius.control, style: .continuous)
                    .stroke(MRColor.frameInk.opacity(isEnabled ? 0.55 : 0.3), lineWidth: 1.1)
            }
            .scaleEffect(!reduceMotion && configuration.isPressed && isEnabled ? 0.982 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct MRPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 섹션 헤더 · 배지

struct MRSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MRColor.primaryText)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(MRType.plate(13))
                        .foregroundStyle(MRColor.brass)
                }
            }
            MRStitch(color: MRColor.frameInk.opacity(0.4))
                .frame(width: 64)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(MRColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MRStatusBadge: View {
    let text: String
    let symbol: String
    var tint: Color = MRColor.accent

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct MRPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xD9E6E6), Color(hex: 0xEDE7DC)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.94))
        }
    }
}

extension Date {
    var mrDayTitle: String {
        formatted(.dateTime.year().month().day().weekday(.abbreviated))
    }

    var mrBoardDate: String {
        formatted(.dateTime.year().month().day().weekday(.abbreviated))
    }

    var mrMonthSection: String {
        formatted(.dateTime.year().month(.wide))
    }
}

extension UIImage {
    static func solid(color: UIColor, size: CGSize = CGSize(width: 16, height: 16)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
