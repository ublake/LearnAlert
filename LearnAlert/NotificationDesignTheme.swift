import SwiftUI

/// Visual treatment only. Color, card state and review behavior stay independent.
public nonisolated enum NotificationDesignTheme: String, CaseIterable, Identifiable, Sendable {
    case liquidGlass = ""
    case soft
    case outline
    case paper
    case arcade
    case minimal

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .soft: "Soft"
        case .outline: "Outline"
        case .paper: "Paper"
        case .arcade: "Arcade"
        case .minimal: "Minimal"
        }
    }

    public func cornerRadius(_ base: CGFloat) -> CGFloat {
        switch self {
        case .liquidGlass: base
        case .soft: max(22, base * 1.6)
        case .outline: min(5, base * 0.25)
        case .paper: min(6, max(2, base * 0.25))
        case .arcade: 2
        case .minimal: min(4, base * 0.2)
        }
    }

    /// Small spacing differences never shrink a control's existing hit target.
    public func verticalPadding(_ base: CGFloat) -> CGFloat {
        switch self {
        case .liquidGlass: base
        case .soft: base + 2
        case .outline: max(8, base - 2)
        case .paper, .arcade: base + 1
        case .minimal: max(8, base - 3)
        }
    }

    public func spacing(_ base: CGFloat) -> CGFloat {
        switch self {
        case .liquidGlass: base
        case .soft, .arcade: base + 2
        case .outline: max(6, base - 1)
        case .paper: base + 1
        case .minimal: max(6, base - 2)
        }
    }
}

private struct NotificationDesignThemeKey: EnvironmentKey {
    static let defaultValue: NotificationDesignTheme? = nil
}

public extension EnvironmentValues {
    /// Nil leaves shared study controls in their ordinary in-app design.
    var notificationDesignTheme: NotificationDesignTheme? {
        get { self[NotificationDesignThemeKey.self] }
        set { self[NotificationDesignThemeKey.self] = newValue }
    }
}

private struct NotificationControlSurfaceModifier: ViewModifier {
    let baseCornerRadius: CGFloat
    let tint: Color?
    let isLight: Bool
    let customBorderColor: Color?
    @Environment(\.notificationDesignTheme) private var selectedDesign
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var design: NotificationDesignTheme { selectedDesign ?? .liquidGlass }
    private var ink: Color { isLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : .white }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: design.cornerRadius(baseCornerRadius), style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch design {
        case .liquidGlass:
            liquidGlass(content)
        case .soft:
            content
                .background {
                    shape.fill(isLight ? Color.white.opacity(0.9) : Color(red: 0.18, green: 0.20, blue: 0.26).opacity(0.96))
                    shape.fill(tint ?? .clear)
                }
                .overlay {
                    shape.strokeBorder(customBorderColor ?? ink.opacity(isLight ? 0.10 : 0.15), lineWidth: customBorderColor == nil ? 0.8 : 1.8)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(isLight ? 0.07 : 0.18), radius: 5, y: 2)
        case .outline:
            content
                .background {
                    shape.fill(reduceTransparency ? opaqueSurface : Color.white.opacity(isLight ? 0.10 : 0.025))
                    shape.fill(tint ?? .clear)
                }
                .overlay {
                    shape.strokeBorder(customBorderColor ?? ink.opacity(isLight ? 0.48 : 0.54), lineWidth: customBorderColor == nil ? 1.4 : 2)
                        .allowsHitTesting(false)
                }
        case .paper:
            content
                .background {
                    shape.fill(isLight ? Color(red: 0.99, green: 0.98, blue: 0.95) : Color(red: 0.19, green: 0.19, blue: 0.21))
                    shape.fill(tint ?? .clear)
                }
                .overlay {
                    shape.strokeBorder(customBorderColor ?? ink.opacity(isLight ? 0.25 : 0.3), lineWidth: customBorderColor == nil ? 1 : 1.8)
                        .allowsHitTesting(false)
                }
                .shadow(color: ink.opacity(isLight ? 0.16 : 0.10), radius: 0, x: 2, y: 3)
        case .arcade:
            content
                .background {
                    shape.fill(isLight ? Color.white : Color(red: 0.055, green: 0.065, blue: 0.095))
                    shape.fill(tint ?? .clear)
                }
                .overlay {
                    shape.strokeBorder(customBorderColor ?? ink.opacity(0.78), lineWidth: 2.5)
                        .allowsHitTesting(false)
                }
                .shadow(color: isLight ? ink.opacity(0.40) : Color.black.opacity(0.75), radius: 0, x: 3, y: 4)
        case .minimal:
            content
                .background {
                    shape.fill(reduceTransparency ? opaqueSurface : Color.white.opacity(isLight ? 0.20 : 0.045))
                    shape.fill(tint ?? .clear)
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(customBorderColor ?? ink.opacity(isLight ? 0.34 : 0.38))
                        .frame(width: customBorderColor == nil ? 2 : 3)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
        }
    }

    private var opaqueSurface: Color {
        isLight ? Color(red: 0.95, green: 0.97, blue: 1) : Color(red: 0.12, green: 0.14, blue: 0.19)
    }

    @ViewBuilder
    private func liquidGlass(_ content: Content) -> some View {
        if reduceTransparency {
            content
                .background {
                    shape.fill(opaqueSurface)
                    shape.fill(tint ?? .clear)
                }
                .overlay {
                    shape.stroke(customBorderColor ?? ink.opacity(0.25), lineWidth: customBorderColor == nil ? 1 : 1.5)
                        .allowsHitTesting(false)
                }
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: baseCornerRadius))
                .overlay {
                    shape.stroke(customBorderColor ?? (isLight ? Color.white.opacity(0.85) : Color.white.opacity(0.18)),
                        lineWidth: customBorderColor == nil ? 1 : 1.5)
                        .allowsHitTesting(false)
                }
                .shadow(color: isLight ? Color.black.opacity(0.05) : Color.black.opacity(0.22),
                    radius: isLight ? 6 : 10, y: isLight ? 2 : 4)
        } else {
            content
                .background(tint ?? (isLight ? Color.white.opacity(0.65) : Color(red: 0.08, green: 0.10, blue: 0.20).opacity(0.65)), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(customBorderColor ?? (isLight ? Color.white.opacity(0.88) : Color.white.opacity(0.20)),
                        lineWidth: customBorderColor == nil ? 1 : 1.5)
                        .allowsHitTesting(false)
                }
                .shadow(color: isLight ? Color.black.opacity(0.05) : Color.black.opacity(0.22),
                    radius: isLight ? 6 : 10, y: isLight ? 2 : 4)
        }
    }
}

private struct NotificationPrimaryActionModifier: ViewModifier {
    @Environment(\.notificationDesignTheme) private var design

    @ViewBuilder
    func body(content: Content) -> some View {
        if design == nil || design == .liquidGlass {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(NotificationPrimaryActionButtonStyle())
        }
    }
}

private struct NotificationPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notificationDesignTheme) private var design
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(Color.primary)
            .notificationControlSurface(cornerRadius: 14, tint: Color.accentColor.opacity(0.15), isLight: colorScheme == .light)
            .contentShape(RoundedRectangle(cornerRadius: (design ?? .liquidGlass).cornerRadius(14), style: .continuous))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

public extension View {
    func notificationControlSurface(cornerRadius: CGFloat = 16, tint: Color? = nil,
                                    isLight: Bool = false, customBorderColor: Color? = nil) -> some View {
        modifier(NotificationControlSurfaceModifier(baseCornerRadius: cornerRadius, tint: tint,
            isLight: isLight, customBorderColor: customBorderColor))
    }

    /// Shared card controls keep their native style outside the notification's optional theme.
    func notificationPrimaryActionStyle() -> some View {
        modifier(NotificationPrimaryActionModifier())
    }
}
