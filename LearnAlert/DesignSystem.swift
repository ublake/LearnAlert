import SwiftUI
import UIKit

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
    static let textPrimary = Color.adaptive(light: UIColor(red: 0.13, green: 0.18, blue: 0.36, alpha: 1), dark: UIColor(red: 0.93, green: 0.94, blue: 1, alpha: 1))
    static let textSecondary = Color.adaptive(light: UIColor(red: 0.36, green: 0.42, blue: 0.58, alpha: 1), dark: UIColor(red: 0.66, green: 0.69, blue: 0.80, alpha: 1))
    static let hairline = Color.adaptive(light: UIColor(red: 0.72, green: 0.78, blue: 0.91, alpha: 1), dark: UIColor(red: 0.25, green: 0.27, blue: 0.38, alpha: 1))
    static let surface = Color.adaptive(light: UIColor(white: 1, alpha: 0.92), dark: UIColor(red: 0.17, green: 0.20, blue: 0.31, alpha: 0.94))
    static let solidPanel = Color(red: 0.055, green: 0.065, blue: 0.12)
    static let solidField = Color(red: 0.025, green: 0.03, blue: 0.065)
    static let courseCanvas = Color.adaptive(light: UIColor(red: 0.976, green: 0.984, blue: 1, alpha: 1), dark: UIColor(red: 0.12, green: 0.15, blue: 0.24, alpha: 1))
    static let courseSurface = Color.adaptive(light: .white, dark: UIColor(red: 0.18, green: 0.21, blue: 0.32, alpha: 0.96))
    static let courseLavender = Color.adaptive(light: UIColor(red: 0.925, green: 0.914, blue: 0.985, alpha: 1), dark: UIColor(red: 0.25, green: 0.23, blue: 0.43, alpha: 1))
    static let glassTint = Color.adaptive(light: UIColor(white: 1, alpha: 0.30), dark: UIColor(white: 1, alpha: 0.10))
    static let glassStroke = Color.adaptive(light: UIColor(white: 1, alpha: 0.58), dark: UIColor(white: 1, alpha: 0.14))
}

struct CoursezyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0.16, green: 0.34, blue: 0.43),
                        Color(red: 0.20, green: 0.27, blue: 0.50),
                        Color(red: 0.31, green: 0.20, blue: 0.52)
                    ]
                    : [
                        Color(red: 0.70, green: 0.88, blue: 0.89),
                        Color(red: 0.75, green: 0.84, blue: 0.91),
                        Color(red: 0.84, green: 0.81, blue: 0.93)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.38))
                .frame(width: 320, height: 320)
                .blur(radius: 54)
                .offset(x: 170, y: -330)
            Circle()
                .fill(LearnAlertStyle.aqua.opacity(0.24))
                .frame(width: 300, height: 300)
                .blur(radius: 58)
                .offset(x: -170, y: 330)
        }
        .ignoresSafeArea()
    }
}

struct AppSectionHeader: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Poppins-SemiBold", size: 28, relativeTo: .largeTitle))
                .foregroundStyle(LearnAlertStyle.textPrimary)
            Text(subtitle)
                .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 7)
        .task {
            withAnimation(.easeOut(duration: 0.46)) { isVisible = true }
        }
    }
}

enum DeckColorPalette {
    static let colors = [
        "#3B82C4", "#6557C9", "#2A9D8F", "#C05A78", "#B8793E", "#397A68",
        "#7654A8", "#287D9B", "#B55245", "#4F70B8", "#8B5E83", "#3D8A59",
        "#A45C40", "#5369A5", "#2F8B83", "#9B6541", "#5B67B3", "#AA526B",
        "#31758D", "#6C7140", "#7A529C", "#3E8068", "#A35E34", "#496FA3"
    ]

    private static let remainingKey = "remainingAutomaticDeckColors"

    static func suggestedColor(existingColors: [String]) -> String {
        preparedColors(existingColors: existingColors).first ?? colors[0]
    }

    static func takeNextColor(existingColors: [String]) -> String {
        var remaining = preparedColors(existingColors: existingColors)
        let selected = remaining.removeFirst()
        UserDefaults.standard.set(remaining, forKey: remainingKey)
        return selected
    }

    private static func preparedColors(existingColors: [String]) -> [String] {
        var remaining = (UserDefaults.standard.stringArray(forKey: remainingKey) ?? [])
            .filter(colors.contains)
        if remaining.isEmpty {
            remaining = colors.shuffled()
        }

        let used = Set(existingColors.map { $0.uppercased() })
        if let unusedIndex = remaining.firstIndex(where: { !used.contains($0.uppercased()) }) {
            let unused = remaining.remove(at: unusedIndex)
            remaining.insert(unused, at: 0)
        } else if used.count < colors.count {
            let unusedColors = colors.filter { !used.contains($0.uppercased()) }
            if let selected = unusedColors.randomElement() {
                remaining.removeAll { $0.caseInsensitiveCompare(selected) == .orderedSame }
                remaining.insert(selected, at: 0)
            }
        }
        UserDefaults.standard.set(remaining, forKey: remainingKey)
        return remaining
    }
}

struct LearnAlertBackground: View {
    var emphasized = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: emphasized
                    ? [Color(red: 0.17, green: 0.31, blue: 0.47), Color(red: 0.28, green: 0.24, blue: 0.68), Color(red: 0.10, green: 0.43, blue: 0.48)]
                    : [Color(red: 0.20, green: 0.63, blue: 0.59), Color(red: 0.22, green: 0.42, blue: 0.68), Color(red: 0.20, green: 0.18, blue: 0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.12, green: 0.61, blue: 0.53).opacity(emphasized ? 0.58 : 0.82))
                .frame(width: 360, height: 360)
                .blur(radius: 58)
                .offset(x: -170, y: -290)

            Circle()
                .fill(Color(red: 0.12, green: 0.48, blue: 0.66).opacity(emphasized ? 0.48 : 0.72))
                .frame(width: 330, height: 330)
                .blur(radius: 62)
                .offset(x: 190, y: -70)

            Circle()
                .fill(Color(red: 0.12, green: 0.64, blue: 0.45).opacity(emphasized ? 0.34 : 0.54))
                .frame(width: 290, height: 290)
                .blur(radius: 64)
                .offset(x: -150, y: 270)

            Circle()
                .fill(Color(red: 0.27, green: 0.31, blue: 0.73).opacity(0.72))
                .frame(width: 350, height: 350)
                .blur(radius: 68)
                .offset(x: 180, y: 430)

            Capsule()
                .fill(Color(red: 0.17, green: 0.53, blue: 0.62).opacity(0.34))
                .frame(width: 410, height: 105)
                .rotationEffect(.degrees(-24))
                .blur(radius: 24)
                .offset(x: 115, y: -235)

            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(Color(red: 0.29, green: 0.22, blue: 0.70).opacity(0.34))
                .frame(width: 310, height: 180)
                .rotationEffect(.degrees(18))
                .blur(radius: 34)
                .offset(x: -170, y: 80)

            Circle()
                .fill(Color(red: 0.14, green: 0.55, blue: 0.43).opacity(0.32))
                .frame(width: 150, height: 150)
                .blur(radius: 20)
                .offset(x: 125, y: 245)

            ContourLines()
                .stroke(
                    Color.white.opacity(emphasized ? 0.09 : 0.12),
                    lineWidth: 1
                )
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct ContourBackdrop: Shape {
    func path(in rect: CGRect) -> Path {
        ContourLines().path(in: rect)
    }
}

private struct ContourLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centers = [
            CGPoint(x: rect.maxX + 15, y: rect.minY + 75),
            CGPoint(x: rect.minX - 20, y: rect.maxY - 50),
            CGPoint(x: rect.midX + 35, y: rect.midY - 40)
        ]

        for center in centers {
            for radius in stride(from: CGFloat(42), through: CGFloat(250), by: 28) {
                path.addEllipse(
                    in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
            }
        }
        return path
    }
}

struct EditorialSurface: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frostedSurface(cornerRadius: 20)
    }
}

extension View {
    @ViewBuilder
    func clearGlassSurface(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(Color.white.opacity(0.06), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 0.75))
        }
    }

    func lightModeGlassElevation(cornerRadius: CGFloat = 20) -> some View {
        modifier(LightModeGlassElevation(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func settingsGlassSurface(cornerRadius: CGFloat = 18) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .background(Color.white.opacity(0.05), in: shape)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .shadow(color: LearnAlertStyle.figmaBlue.opacity(0.07), radius: 12, y: 6)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .background(Color.white.opacity(0.28), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.45), lineWidth: 0.75))
                .shadow(color: LearnAlertStyle.figmaBlue.opacity(0.07), radius: 12, y: 6)
        }
    }

    @ViewBuilder
    func liquidGlassInput(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    shape
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(Color.white.opacity(0.06), in: shape)
                .overlay(
                    shape
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.40), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
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

private extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
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
