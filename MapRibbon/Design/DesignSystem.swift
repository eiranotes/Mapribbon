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
    static let background = Color(hex: 0xF6F5F1)
    static let surface = Color.white
    static let secondarySurface = Color(hex: 0xEEEDE8)
    static let primaryText = Color(hex: 0x171815)
    static let secondaryText = Color(hex: 0x6D6F68)
    static let tertiaryText = Color(hex: 0x989A93)
    static let border = Color(hex: 0xDDDDD6)
    static let accent = Color(hex: 0xE86652)
    static let accentPressed = Color(hex: 0xD85845)
    static let accentSoft = Color(hex: 0xF7E3DE)
    static let success = Color(hex: 0x3C7A57)
    static let warning = Color(hex: 0xA46B23)
    static let paper = Color(hex: 0xF4EFE5)
    static let ink = Color(hex: 0x26241F)
    static let thread = Color(hex: 0xD95849)
    static let scrim = Color.black.opacity(0.42)
}

enum MRSpacing {
    static let screen: CGFloat = 20
    static let section: CGFloat = 24
    static let card: CGFloat = 16
    static let compact: CGFloat = 8
    static let control: CGFloat = 12
}

enum MRMotion {
    static let quick = Animation.easeOut(duration: 0.14)
    static let standard = Animation.easeOut(duration: 0.22)
    static let spatial = Animation.interactiveSpring(duration: 0.32, extraBounce: 0.08)
}

struct MRCardModifier: ViewModifier {
    var padding: CGFloat = MRSpacing.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MRColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MRColor.border.opacity(0.86), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 8, y: 3)
    }
}

extension View {
    func mrCard(padding: CGFloat = MRSpacing.card) -> some View {
        modifier(MRCardModifier(padding: padding))
    }
}

struct MRPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(configuration.isPressed ? MRColor.accentPressed : MRColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(MRMotion.quick, value: configuration.isPressed)
    }
}

struct MRSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(MRColor.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(MRColor.secondarySurface.opacity(configuration.isPressed ? 0.68 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MRColor.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(MRMotion.quick, value: configuration.isPressed)
    }
}

struct MRPressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(MRMotion.quick, value: configuration.isPressed)
    }
}

struct MRIconButtonStyle: ButtonStyle {
    var tint: Color = MRColor.primaryText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(MRColor.surface.opacity(configuration.isPressed ? 0.72 : 0.94))
            .clipShape(Circle())
            .overlay { Circle().stroke(MRColor.border, lineWidth: 1) }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(MRMotion.quick, value: configuration.isPressed)
    }
}

struct MRSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MRColor.primaryText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct MRSelectionChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? MRColor.accent : MRColor.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isSelected ? MRColor.accentSoft : MRColor.surface)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(isSelected ? MRColor.accent : MRColor.border, lineWidth: 1)
            }
    }
}

struct MRPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            Color(hex: 0xE5E6E1)
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.94))
        }
    }
}

struct MRLoadingRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(MRColor.border, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(MRColor.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(MRColor.primaryText)
        }
        .frame(width: 116, height: 116)
        .animation(.easeInOut(duration: 0.24), value: progress)
    }
}

struct MRBottomActionBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, MRSpacing.screen)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider().opacity(0.55) }
    }
}

extension Section where Parent == Text, Footer == Text {
    init(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            content: content,
            header: { Text(title) },
            footer: footer
        )
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
