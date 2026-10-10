import SwiftUI
import UIKit
import AVKit
import AVFoundation

enum LearnAlertStyle {
    // Core palette sampled from the LearnAlert visual direction.
    static let aqua = Color(red: 0.224, green: 0.816, blue: 0.737)       // 39D0BC
    static let cyan = Color(red: 0.227, green: 0.710, blue: 0.796)       // 3AB5CB
    static let mint = Color(red: 0.239, green: 0.859, blue: 0.655)       // 3DDBA7
    // Adaptive vibrant electric azure/sapphire - replaces old harsh dark blue
    static let indigo = Color.adaptive(
        light: UIColor(red: 0.12, green: 0.48, blue: 0.96, alpha: 1), // Lively Apple Azure #1F7CF5
        dark: UIColor(red: 0.28, green: 0.60, blue: 1.0, alpha: 1)    // Luminous Azure #4799FF
    )
    static let deckPrimaryAccent = Color.adaptive(
        light: UIColor(red: 0.10, green: 0.48, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.25, green: 0.60, blue: 1.0, alpha: 1)
    )
    static let green = Color(red: 0.271, green: 0.910, blue: 0.600)      // 45E899
    static let sky = Color(red: 0.290, green: 0.592, blue: 0.812)        // 4A97CF
    static let blue = Color.adaptive(
        light: UIColor(red: 0.15, green: 0.46, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.32, green: 0.62, blue: 1.0, alpha: 1)
    )
    static let periwinkle = Color(red: 0.361, green: 0.439, blue: 0.878) // 5C70E0
    static let figmaBlue = Color(red: 0.239, green: 0.561, blue: 0.937)   // 3D8FEF

    static let canvas = Color(red: 0.82, green: 0.96, blue: 0.95)
    static let canvasDeep = indigo
    static let indigoDeep = Color.adaptive(
        light: UIColor(red: 0.08, green: 0.26, blue: 0.60, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.14, blue: 0.28, alpha: 1)
    )
    static let coral = Color(red: 0.91, green: 0.34, blue: 0.38)
    static let destructiveRed = Color.adaptive(light: UIColor(red: 0.82, green: 0.20, blue: 0.25, alpha: 1), dark: UIColor(red: 0.95, green: 0.40, blue: 0.45, alpha: 1))
    static let lime = green
    static let textPrimary = Color.adaptive(light: UIColor(red: 0.15, green: 0.18, blue: 0.21, alpha: 1), dark: UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1))
    static let textSecondary = Color.adaptive(light: UIColor(red: 0.39, green: 0.43, blue: 0.47, alpha: 1), dark: UIColor(red: 0.67, green: 0.69, blue: 0.74, alpha: 1))
    static let hairline = Color.adaptive(light: UIColor(red: 0.72, green: 0.78, blue: 0.91, alpha: 1), dark: UIColor(red: 0.24, green: 0.25, blue: 0.29, alpha: 1))
    static let surface = Color.adaptive(light: UIColor(white: 1, alpha: 0.92), dark: UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1))
    static let solidPanel = Color(red: 0.055, green: 0.065, blue: 0.12)
    static let solidField = Color(red: 0.025, green: 0.03, blue: 0.065)
    static let courseCanvas = Color.adaptive(light: UIColor(red: 0.969, green: 0.977, blue: 0.986, alpha: 1), dark: UIColor(red: 0.075, green: 0.080, blue: 0.095, alpha: 1))
    static let courseSurface = Color.adaptive(light: .white, dark: UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1))
    // A translucent baby-blue fill with separate readable ink for labels and links.
    // Notification themes and course identity colors keep their own palettes.
    static let appAccent = Color.adaptive(
        light: UIColor(red: 0.65, green: 0.81, blue: 0.95, alpha: 0.88),
        dark: UIColor(red: 0.66, green: 0.83, blue: 0.97, alpha: 0.88)
    )
    static let appAccentInk = Color(red: 0.105, green: 0.225, blue: 0.34)
    static let appAccentForeground = Color.adaptive(
        light: UIColor(red: 0.22, green: 0.40, blue: 0.56, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.83, blue: 0.97, alpha: 1)
    )
    // Opaque app surfaces keep controls distinct in either appearance.
    static let insetSurface = Color.adaptive(
        light: UIColor(red: 0.929, green: 0.953, blue: 0.977, alpha: 1),
        dark: UIColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 1)
    )
    static let cardBorder = Color.adaptive(
        light: UIColor(red: 0.85, green: 0.89, blue: 0.93, alpha: 1),
        dark: UIColor(white: 1, alpha: 0.07)
    )
    static let cardShadow = Color.adaptive(
        light: UIColor(red: 0.08, green: 0.16, blue: 0.30, alpha: 0.045),
        dark: UIColor(white: 0, alpha: 0.12)
    )
    static let courseLavender = Color.adaptive(light: UIColor(red: 0.925, green: 0.914, blue: 0.985, alpha: 1), dark: UIColor(red: 0.25, green: 0.23, blue: 0.43, alpha: 1))
    static let glassTint = Color.adaptive(light: UIColor(white: 1, alpha: 0.30), dark: UIColor(white: 1, alpha: 0.10))
    static let glassStroke = Color.adaptive(light: UIColor(white: 1, alpha: 0.58), dark: UIColor(white: 1, alpha: 0.14))
}

struct CoursezyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LearnAlertStyle.courseCanvas
            .ignoresSafeArea()
    }
}

// MARK: - LearnAlert Logo Mark
struct LearnAlertLogoMark: View {
    var body: some View {
        Image("LearnAlertLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
    }
}

// MARK: - App Section Header
struct AppSectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Poppins-SemiBold", size: 24, relativeTo: .title))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
            }
        }
    }
}


// MARK: - View Modifiers
struct EditorialSurface: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(LearnAlertStyle.courseSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LearnAlertStyle.hairline.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}

extension View {
    func appCardSurface(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(LearnAlertStyle.courseSurface, in: shape)
            .overlay(shape.strokeBorder(LearnAlertStyle.cardBorder, lineWidth: 1))
            .shadow(color: LearnAlertStyle.cardShadow, radius: 10, y: 4)
    }

    func clearGlassSurface(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 14, y: 5)
    }

    func liquidGlassInput(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(LearnAlertStyle.courseSurface.opacity(0.85), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LearnAlertStyle.glassStroke, lineWidth: 1)
            )
    }

    func lightModeGlassElevation(cornerRadius: CGFloat = 20) -> some View {
        modifier(LightModeGlassElevation(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func liquidGlassCircle(interactive: Bool = true, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            let glass: Glass = {
                if let tint {
                    return .regular.tint(tint).interactive(interactive)
                } else {
                    return .clear.interactive(interactive)
                }
            }()
            self.glassEffect(glass, in: .circle)
        } else {
            self
                .background(.ultraThinMaterial, in: Circle())
                .background((tint ?? Color.white.opacity(0.12)), in: Circle())
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
        }
    }

    func coursezyCard(cornerRadius: CGFloat = 20, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frostedSurface(cornerRadius: cornerRadius)
    }

    func coursezyField(cornerRadius: CGFloat = 14) -> some View {
        self
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .frostedSurface(cornerRadius: cornerRadius, shadowRadius: 5)
    }

    func editorialSurface(padding: CGFloat = 16) -> some View {
        modifier(EditorialSurface(padding: padding))
    }

    func editorialField() -> some View {
        padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LearnAlertStyle.hairline.opacity(0.4)))
    }

    func nativeGlass(cornerRadius: CGFloat = 18) -> some View {
        frostedSurface(cornerRadius: cornerRadius)
    }

    func settingsGlassSurface(cornerRadius: CGFloat = 18) -> some View {
        appCardSurface(cornerRadius: cornerRadius)
    }

    func solidDarkSurface(cornerRadius: CGFloat = 10) -> some View {
        background(LearnAlertStyle.solidPanel)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    func solidDarkField(cornerRadius: CGFloat = 7) -> some View {
        padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(LearnAlertStyle.solidField)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    func interactiveGlass(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        frostedSurface(cornerRadius: cornerRadius, tint: tint)
    }

    func frostedSurface(cornerRadius: CGFloat, tint: Color? = nil, shadowRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(.ultraThinMaterial, in: shape)
            .background(tint ?? LearnAlertStyle.glassTint, in: shape)
            .overlay(shape.stroke(LearnAlertStyle.glassStroke, lineWidth: 0.8))
            .shadow(color: LearnAlertStyle.indigoDeep.opacity(0.10), radius: shadowRadius, y: 6)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LightModeGlassElevation: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .light ? Color.white.opacity(0.72) : Color.clear,
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.16) : Color.clear,
                radius: 15,
                y: 8
            )
    }
}

extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

enum LearnAlertButtonKind {
    case filled
    case outline
    case gradient
}

enum LearnAlertButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small, .medium: 44
        case .large: 48
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 12
        case .medium: 16
        case .large: 20
        }
    }

    var font: Font {
        switch self {
        case .small:
            .custom("Poppins-Regular", size: 13, relativeTo: .caption)
        case .medium:
            .custom("Poppins-Regular", size: 15, relativeTo: .subheadline)
        case .large:
            .custom("Poppins-Regular", size: 16, relativeTo: .body)
        }
    }
}

struct LearnAlertButtonStyle: ButtonStyle {
    var kind: LearnAlertButtonKind = .filled
    var size: LearnAlertButtonSize = .large
    var color: Color = LearnAlertStyle.indigo
    var expands = false

    func makeBody(configuration: Configuration) -> some View {
        LearnAlertButtonStyleBody(
            configuration: configuration,
            kind: kind,
            size: size,
            color: color,
            expands: expands
        )
    }
}

private struct LearnAlertButtonStyleBody: View {
    @Environment(\.isEnabled) private var isEnabled

    let configuration: ButtonStyleConfiguration
    let kind: LearnAlertButtonKind
    let size: LearnAlertButtonSize
    let color: Color
    let expands: Bool

    private var foregroundStyle: AnyShapeStyle {
        kind == .outline ? AnyShapeStyle(color) : AnyShapeStyle(.white)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch kind {
        case .filled:
            AnyShapeStyle(color)
        case .outline:
            AnyShapeStyle(.clear)
        case .gradient:
            AnyShapeStyle(
                LinearGradient(
                    colors: [color.opacity(0.68), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    var body: some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundStyle)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(minHeight: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(kind == .outline ? color : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LearnAlertButtonStyle(
            kind: .filled,
            size: .large,
            color: LearnAlertStyle.indigo,
            expands: true
        )
        .makeBody(configuration: configuration)
    }
}


@MainActor
enum HapticFeedback {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}


struct AIMarkdownText: View {
    let text: String
    var size: CGFloat = 15
    var color: Color = .white
    var lineSpacing: CGFloat = 3

    var body: some View {
        Text(attributedString)
            .lineSpacing(lineSpacing)
    }

    private var attributedString: AttributedString {
        do {
            var attr = try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
            for run in attr.runs {
                if let intent = run.inlinePresentationIntent, intent.contains(.stronglyEmphasized) {
                    attr[run.range].font = .custom("Poppins-SemiBold", size: size)
                    attr[run.range].foregroundColor = color
                } else if let intent = run.inlinePresentationIntent, intent.contains(.emphasized) {
                    attr[run.range].font = .custom("Poppins-Regular", size: size).italic()
                    attr[run.range].foregroundColor = color
                } else if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                    attr[run.range].font = .system(size: size - 1, weight: .medium, design: .monospaced)
                    attr[run.range].foregroundColor = LearnAlertStyle.aqua
                } else {
                    attr[run.range].font = .custom("Poppins-Regular", size: size)
                    attr[run.range].foregroundColor = color
                }
            }
            return attr
        } catch {
            var fallback = AttributedString(text)
            fallback.font = .custom("Poppins-Regular", size: size)
            fallback.foregroundColor = color
            return fallback
        }
    }
}
