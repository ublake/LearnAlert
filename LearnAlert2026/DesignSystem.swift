import SwiftUI

enum LearnAlertStyle {
    static let canvas = Color(red: 0.93, green: 0.96, blue: 1.0)
    static let canvasDeep = Color(red: 0.86, green: 0.92, blue: 0.99)
    static let indigo = Color(red: 0.29, green: 0.34, blue: 0.82)
    static let indigoDeep = Color(red: 0.20, green: 0.25, blue: 0.68)
    static let sky = Color(red: 0.34, green: 0.67, blue: 0.91)
    static let coral = Color(red: 0.91, green: 0.34, blue: 0.38)
    static let lime = Color(red: 0.38, green: 0.74, blue: 0.08)
    static let textPrimary = Color(red: 0.13, green: 0.18, blue: 0.36)
    static let textSecondary = Color(red: 0.36, green: 0.42, blue: 0.58)
    static let hairline = Color(red: 0.72, green: 0.78, blue: 0.91)
    static let surface = Color.white.opacity(0.92)
}

struct LearnAlertBackground: View {
    var emphasized = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: emphasized
                    ? [LearnAlertStyle.indigo, LearnAlertStyle.indigoDeep]
                    : [LearnAlertStyle.canvas, LearnAlertStyle.canvasDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ContourLines()
                .stroke(
                    emphasized ? Color.white.opacity(0.09) : LearnAlertStyle.indigo.opacity(0.07),
                    lineWidth: 1
                )
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct ContourLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centers = [
            CGPoint(x: rect.maxX + 15, y: rect.minY + 75),
            CGPoint(x: rect.minX - 20, y: rect.maxY - 50)
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
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LearnAlertStyle.hairline.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: LearnAlertStyle.indigo.opacity(0.08), radius: 14, y: 8)
    }
}

extension View {
    func editorialSurface(padding: CGFloat = 16) -> some View {
        modifier(EditorialSurface(padding: padding))
    }

    func editorialField() -> some View {
        padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LearnAlertStyle.indigo.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
