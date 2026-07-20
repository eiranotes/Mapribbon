import SwiftUI
import UIKit

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
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x121619) : UIColor(hex: 0xF1F3F4)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x1A2024) : UIColor(hex: 0xF7F8F8)
    })
    static let elevatedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x20272B) : UIColor(hex: 0xFFFFFF)
    })
    static let secondarySurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x283035) : UIColor(hex: 0xE7EBED)
    })
    static let primaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xF5F6F6) : UIColor(hex: 0x1B252B)
    })
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xB1BBC0) : UIColor(hex: 0x647078)
    })
    static let tertiaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x7F8A90) : UIColor(hex: 0x929CA1)
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x384247) : UIColor(hex: 0xD4DADD)
    })
    static let accent = Color(hex: 0xD84A36)
    static let accentPressed = Color(hex: 0xB93B2B)
    static let accentSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x452821) : UIColor(hex: 0xF6E4DF)
    })
    static let mapTeal = Color(hex: 0x347A7A)
    static let mapTealSoft = Color(hex: 0xDCECEB)
    static let success = Color(hex: 0x39735A)
    static let warning = Color(hex: 0x9A6728)
    static let paper = Color(hex: 0xF4EFE5)
    static let paperBright = Color(hex: 0xFAF7EF)
    static let ink = Color(hex: 0x1B252B)
    static let cork = Color(hex: 0xA97845)
    static let brass = Color(hex: 0xB28A48)
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
    static let compact: CGFloat = 10
    static let control: CGFloat = 12
    static let card: CGFloat = 14
    static let sheet: CGFloat = 22
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
                    .stroke(MRColor.border.opacity(0.68), lineWidth: 0.7)
            }
            .shadow(color: shadow ? Color.black.opacity(0.07) : .clear, radius: 10, y: 4)
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

    func mrPaper(padding: CGFloat = MRSpacing.card) -> some View {
        modifier(MRPaperModifier(padding: padding))
    }
}

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
                    .stroke(MRColor.border.opacity(isEnabled ? 0.8 : 0.35), lineWidth: 0.8)
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

struct MRSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MRColor.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(MRColor.secondaryText)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MRColor.accent)
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

struct MRLoadingRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(MRColor.border.opacity(0.42), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(MRColor.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(MRColor.primaryText)
        }
        .frame(width: 108, height: 108)
        .animation(.easeInOut(duration: 0.22), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("보드 생성 진행률")
        .accessibilityValue("\(Int(progress * 100))퍼센트")
    }
}

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
