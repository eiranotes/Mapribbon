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
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .systemBackground)
    static let secondarySurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let border = Color(uiColor: .separator)
    static let accent = Color(hex: 0xE86652)
    static let accentSoft = Color(hex: 0xF7E3DE)
    static let success = Color(hex: 0x3C7A57)
    static let warning = Color(hex: 0xA46B23)
    static let paper = Color(hex: 0xF4EFE5)
    static let paperBright = Color(hex: 0xFBF8F0)
    static let ink = Color(hex: 0x26241F)
    static let cork = Color(hex: 0xA97845)
}

enum MRSpacing {
    static let screen: CGFloat = 20
    static let section: CGFloat = 24
    static let card: CGFloat = 16
    static let compact: CGFloat = 8
    static let tight: CGFloat = 4
}

struct MRCardModifier: ViewModifier {
    var padding: CGFloat = MRSpacing.card
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MRColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MRColor.border.opacity(0.55), lineWidth: 0.7)
            }
            .shadow(color: shadow ? Color.black.opacity(0.055) : .clear, radius: 12, y: 5)
    }
}

extension View {
    func mrCard(padding: CGFloat = MRSpacing.card, shadow: Bool = true) -> some View {
        modifier(MRCardModifier(padding: padding, shadow: shadow))
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
            .background(MRColor.accent.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.34))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .scaleEffect(!reduceMotion && configuration.isPressed && isEnabled ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
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
            .background(MRColor.elevatedSurface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MRColor.border.opacity(isEnabled ? 0.7 : 0.35), lineWidth: 0.8)
            }
            .scaleEffect(!reduceMotion && configuration.isPressed && isEnabled ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct MRPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
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
                colors: [Color(hex: 0xDCE9EA), Color(hex: 0xF2E3D5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

struct MRLoadingRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(MRColor.border.opacity(0.42), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(MRColor.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(MRColor.primaryText)
        }
        .frame(width: 112, height: 112)
        .animation(.easeInOut(duration: 0.24), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("보드 생성 진행률")
        .accessibilityValue("\(Int(progress * 100))퍼센트")
    }
}

extension Date {
    var mrDayTitle: String {
        formatted(.dateTime.year().month().day().weekday(.abbreviated))
    }

    var mrBoardDate: String {
        formatted(.dateTime.year().month().day().weekday(.abbreviated))
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
