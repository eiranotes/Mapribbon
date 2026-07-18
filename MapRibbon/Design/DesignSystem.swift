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
    static let background = Color(hex: 0xF7F7F5)
    static let surface = Color.white
    static let secondarySurface = Color(hex: 0xF0F0EC)
    static let primaryText = Color(hex: 0x171815)
    static let secondaryText = Color(hex: 0x6D6F68)
    static let border = Color(hex: 0xDFE0DA)
    static let accent = Color(hex: 0xE86652)
    static let accentSoft = Color(hex: 0xF7E3DE)
    static let success = Color(hex: 0x3C7A57)
    static let warning = Color(hex: 0xA46B23)
    static let paper = Color(hex: 0xF4EFE5)
    static let ink = Color(hex: 0x26241F)
}

enum MRSpacing {
    static let screen: CGFloat = 20
    static let section: CGFloat = 24
    static let card: CGFloat = 16
    static let compact: CGFloat = 8
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
                    .stroke(MRColor.border.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 10, y: 4)
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
            .background(MRColor.accent.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct MRSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(MRColor.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(MRColor.secondarySurface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MRColor.border, lineWidth: 1)
            }
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

struct MRPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xDCE9EA), Color(hex: 0xF2E3D5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

struct MRLoadingRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(MRColor.border, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    MRColor.accent,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(MRColor.primaryText)
        }
        .frame(width: 116, height: 116)
        .animation(.easeInOut(duration: 0.28), value: progress)
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
