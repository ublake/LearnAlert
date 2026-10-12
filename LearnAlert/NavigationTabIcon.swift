import SwiftUI

/// Small vector details share one palette; the inactive state keeps the familiar SF outline.
struct NavigationTabIcon: View {
    let tab: Int
    let outlineSymbol: String
    let isSelected: Bool
    let size: CGFloat
    var weight: Font.Weight = .semibold
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: NavigationIconPalette { NavigationIconPalette(isDark: colorScheme == .dark) }

    var body: some View {
        ZStack {
            Image(systemName: outlineSymbol)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(LearnAlertStyle.textSecondary)
                .opacity(isSelected ? 0 : 1)

            Canvas { context, canvasSize in
                // A common drawing grid keeps the four icons optically balanced at every dock size.
                context.scaleBy(x: canvasSize.width / 32, y: canvasSize.height / 28)
                switch tab {
                case 0: drawCards(in: &context)
                case 1: drawBooks(in: &context)
                case 2: drawSliders(in: &context)
                default: drawGear(in: &context)
                }
            }
            .opacity(isSelected ? 1 : 0)
        }
        .frame(width: size * 1.28, height: size * 1.12)
        .scaleEffect(isSelected && !reduceMotion ? 1.04 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.66), value: isSelected)
        .accessibilityHidden(true)
    }

    private func drawCards(in context: inout GraphicsContext) {
        roundedRect(CGRect(x: 7, y: 2, width: 18, height: 7), radius: 2,
                    fill: palette.yellow, outline: palette.yellowInk, in: &context)
        roundedRect(CGRect(x: 5, y: 6, width: 22, height: 9), radius: 2,
                    fill: palette.peach, outline: palette.peachInk, in: &context)
        roundedRect(CGRect(x: 2.5, y: 11, width: 27, height: 15), radius: 2.5,
                    fill: palette.blue, outline: palette.blueInk, in: &context)
        line(from: CGPoint(x: 7, y: 16), to: CGPoint(x: 19, y: 16),
             color: palette.blueInk.opacity(0.72), width: 1.2, in: &context)
        line(from: CGPoint(x: 7, y: 20), to: CGPoint(x: 14, y: 20),
             color: palette.blueInk.opacity(0.45), width: 1.2, in: &context)
    }

    private func drawBooks(in context: inout GraphicsContext) {
        book(CGRect(x: 2, y: 6, width: 7, height: 20), fill: palette.blue, ink: palette.blueInk, in: &context)
        book(CGRect(x: 11, y: 2, width: 8, height: 24), fill: palette.peach, ink: palette.peachInk, in: &context)
        var leaningBook = context
        leaningBook.translateBy(x: 25, y: 26)
        leaningBook.rotate(by: .degrees(9))
        leaningBook.translateBy(x: -25, y: -26)
        book(CGRect(x: 21, y: 5, width: 7, height: 21), fill: palette.yellow, ink: palette.yellowInk, in: &leaningBook)
    }

    private func book(_ rect: CGRect, fill: Color, ink: Color, in context: inout GraphicsContext) {
        roundedRect(rect, radius: 1.3, fill: fill, outline: ink, in: &context)
        line(from: CGPoint(x: rect.minX + 1.6, y: rect.minY + 2),
             to: CGPoint(x: rect.minX + 1.6, y: rect.maxY - 2),
             color: ink.opacity(0.28), width: 0.7, in: &context)
        for y in [rect.minY + 4, rect.maxY - 4] {
            line(from: CGPoint(x: rect.minX + 2.7, y: y), to: CGPoint(x: rect.maxX - 1.6, y: y),
                 color: ink.opacity(0.7), width: 1, in: &context)
        }
    }

    private func drawSliders(in context: inout GraphicsContext) {
        let rows: [(CGFloat, CGFloat, Color, Color)] = [
            (6, 10, palette.blue, palette.blueInk),
            (14, 23, palette.peach, palette.peachInk),
            (22, 14, palette.yellow, palette.yellowInk)
        ]
        for (y, x, fill, ink) in rows {
            line(from: CGPoint(x: 3, y: y), to: CGPoint(x: 29, y: y),
                 color: LearnAlertStyle.appAccentForeground.opacity(0.65), width: 1.8, in: &context)
            roundedRect(CGRect(x: x - 2.6, y: y - 3.5, width: 5.2, height: 7), radius: 1.4,
                        fill: fill, outline: ink, in: &context)
        }
    }

    private func drawGear(in context: inout GraphicsContext) {
        // Rounded joins soften eight small teeth without losing the settings silhouette.
        var gear = Path()
        let radii: [CGFloat] = [9.1, 9.1, 12, 12, 12, 12, 9.1, 9.1]
        for step in 0..<64 {
            let angle = CGFloat(step) * .pi / 32 - .pi / 2
            let radius = radii[step % radii.count]
            let point = CGPoint(x: 16 + cos(angle) * radius, y: 14 + sin(angle) * radius)
            if step == 0 { gear.move(to: point) } else { gear.addLine(to: point) }
        }
        gear.closeSubpath()
        context.fill(gear, with: .color(palette.blue))
        context.stroke(gear, with: .color(palette.blueInk), style: StrokeStyle(lineWidth: 0.85, lineJoin: .round))
        let hub = Path(ellipseIn: CGRect(x: 10.3, y: 8.3, width: 11.4, height: 11.4))
        context.fill(hub, with: .color(palette.gearHub))
        context.stroke(hub, with: .color(palette.blueInk), lineWidth: 0.7)
        let center = Path(ellipseIn: CGRect(x: 13, y: 11, width: 6, height: 6))
        context.fill(center, with: .color(LearnAlertStyle.courseSurface))
        context.stroke(center, with: .color(palette.blueInk.opacity(0.65)), lineWidth: 0.65)
    }

    private func roundedRect(_ rect: CGRect, radius: CGFloat, fill: Color, outline: Color, in context: inout GraphicsContext) {
        let path = Path(roundedRect: rect, cornerRadius: radius)
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(outline), lineWidth: 0.8)
    }

    private func line(from start: CGPoint, to end: CGPoint, color: Color, width: CGFloat, in context: inout GraphicsContext) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

private struct NavigationIconPalette {
    let isDark: Bool

    var blue: Color {
        isDark ? Color(red: 0.67, green: 0.83, blue: 0.97) : Color(red: 0.57, green: 0.75, blue: 0.92)
    }
    var peach: Color {
        isDark ? Color(red: 0.96, green: 0.73, blue: 0.61) : Color(red: 0.92, green: 0.64, blue: 0.51)
    }
    var gearHub: Color {
        isDark ? Color(red: 0.22, green: 0.42, blue: 0.61) : Color(red: 0.16, green: 0.34, blue: 0.52)
    }
    var yellow: Color {
        isDark ? Color(red: 0.98, green: 0.85, blue: 0.57) : Color(red: 0.92, green: 0.78, blue: 0.43)
    }
    var blueInk: Color {
        isDark ? Color(red: 0.34, green: 0.55, blue: 0.72) : Color(red: 0.27, green: 0.46, blue: 0.63)
    }
    var peachInk: Color {
        isDark ? Color(red: 0.72, green: 0.45, blue: 0.34) : Color(red: 0.65, green: 0.38, blue: 0.29)
    }
    var yellowInk: Color {
        isDark ? Color(red: 0.72, green: 0.59, blue: 0.31) : Color(red: 0.63, green: 0.50, blue: 0.24)
    }
}
