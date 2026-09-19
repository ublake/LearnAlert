import SwiftUI

private struct CanvasNotificationBackdrop: View {
    var isLight: Bool

    var body: some View {
        ZStack {
            if isLight {
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.96, blue: 1.0),
                        Color(red: 0.88, green: 0.93, blue: 0.98),
                        Color(red: 0.93, green: 0.90, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.20, green: 0.72, blue: 0.95).opacity(0.20))
                    .frame(width: 260, height: 260)
                    .blur(radius: 46)
                    .offset(x: 140, y: -180)

                Circle()
                    .fill(Color(red: 0.90, green: 0.35, blue: 0.65).opacity(0.14))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: -140, y: 200)

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(Color(red: 0.15, green: 0.45, blue: 0.85).opacity(0.05), lineWidth: 1)
                        .frame(
                            width: CGFloat(110 + index * 42),
                            height: CGFloat(110 + index * 42)
                        )
                        .offset(x: 140, y: -160)
                }
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.09, blue: 0.20),
                        Color(red: 0.14, green: 0.11, blue: 0.28),
                        Color(red: 0.06, green: 0.18, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.10, green: 0.72, blue: 0.95).opacity(0.28))
                    .frame(width: 260, height: 260)
                    .blur(radius: 46)
                    .offset(x: 140, y: -180)

                Circle()
                    .fill(Color(red: 0.90, green: 0.25, blue: 0.65).opacity(0.22))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: -140, y: 200)

                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(
                            width: CGFloat(110 + index * 42),
                            height: CGFloat(110 + index * 42)
                        )
                        .offset(x: 140, y: -160)
                }
            }
        }
        .clipped()
    }
}

private extension View {
    @ViewBuilder
    func canvasLiquidGlass(
        cornerRadius: CGFloat = 16,
        tint: Color? = nil,
        isLight: Bool = false,
        customBorderColor: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    shape.stroke(
                        customBorderColor ?? (isLight ? Color.white.opacity(0.85) : Color.white.opacity(0.18)),
                        lineWidth: customBorderColor != nil ? 1.5 : 1
                    )
                )
                .shadow(
                    color: isLight ? Color.black.opacity(0.05) : Color.black.opacity(0.22),
                    radius: isLight ? 6 : 10,
                    y: isLight ? 2 : 4
                )
        } else {
            self
                .background(
                    tint ?? (isLight ? Color.white.opacity(0.65) : Color(red: 0.08, green: 0.10, blue: 0.20).opacity(0.65)),
                    in: shape
                )
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(
                        customBorderColor ?? (isLight ? Color.white.opacity(0.88) : Color.white.opacity(0.20)),
                        lineWidth: customBorderColor != nil ? 1.5 : 1
                    )
                )
                .shadow(
                    color: isLight ? Color.black.opacity(0.05) : Color.black.opacity(0.22),
                    radius: isLight ? 6 : 10,
                    y: isLight ? 2 : 4
                )
        }
    }
}

/// Canvas-friendly stand-in for the notification content extension.
struct NotificationCanvasView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAnswer: String?
    @State private var showingHint = false
    @State private var showingControls = false

    private var isLight: Bool { colorScheme == .light }
    private var textColorPrimary: Color {
        isLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : Color.white
    }
    private var textColorSecondary: Color {
        isLight ? Color(red: 0.38, green: 0.44, blue: 0.58) : Color.white.opacity(0.68)
    }

    private let answers = ["Good night", "Good morning", "Good afternoon", "Goodbye"]
    private let correctAnswer = "Good morning"

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
                        Text("SPANISH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(textColorSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .canvasLiquidGlass(cornerRadius: 10, isLight: isLight)

                    Text("3/17")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(textColorSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .canvasLiquidGlass(cornerRadius: 10, isLight: isLight)

                    Spacer()

                    Button {
                        withAnimation(.snappy) {
                            showingControls.toggle()
                        }
                    } label: {
                        Image(systemName: showingControls ? "xmark" : "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textColorPrimary)
                            .frame(width: 36, height: 36)
                            .canvasLiquidGlass(cornerRadius: 18, isLight: isLight)
                    }
                }

                if showingControls {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notification Controls", systemImage: "slider.horizontal.3")
                            .font(.headline.bold())
                            .foregroundStyle(textColorPrimary)
                        Label("Change mini-session deck", systemImage: "rectangle.stack.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(textColorPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(isLight ? Color.white.opacity(0.60) : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Label("Stop scheduled notifications", systemImage: "bell.slash.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(isLight ? 0.12 : 0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(14)
                    .canvasLiquidGlass(cornerRadius: 18, isLight: isLight)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Text("What does “Buenos días” mean?")
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(textColorPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 18)
                    .canvasLiquidGlass(cornerRadius: 20, isLight: isLight)

                VStack(spacing: 11) {
                    ForEach(answers, id: \.self) { answer in
                        Button {
                            guard selectedAnswer == nil else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                selectedAnswer = answer
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(answer)
                                    .font(.system(size: 15, weight: .semibold))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(optionTextColor(answer))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if selectedAnswer != nil {
                                    if answer == correctAnswer {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color.green)
                                    } else if answer == selectedAnswer {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color.red)
                                    }
                                }
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 18)
                            .canvasLiquidGlass(
                                cornerRadius: 16,
                                tint: optionGlassTint(answer),
                                isLight: isLight,
                                customBorderColor: optionBorderColor(answer)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedAnswer != nil)
                    }
                }

                if selectedAnswer == nil {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring) {
                                showingHint.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showingHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                                Text(showingHint ? "Hide Hint" : "Hint").fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(Color.orange)
                            .canvasLiquidGlass(cornerRadius: 12, tint: Color.orange.opacity(0.10), isLight: isLight)
                        }

                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "forward.fill")
                                Text("Skip").fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(textColorSecondary)
                            .canvasLiquidGlass(cornerRadius: 12, isLight: isLight)
                        }
                    }
                }

                if showingHint {
                    Text("This greeting is commonly used before noon.")
                        .font(.subheadline.italic())
                        .foregroundStyle(Color.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .canvasLiquidGlass(cornerRadius: 12, tint: Color.orange.opacity(0.08), isLight: isLight)
                }

                if selectedAnswer != nil {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            previewStat("New", value: 5, icon: "sparkles")
                            previewStat("Learning", value: 2, icon: "brain.head.profile")
                            previewStat("Mastered", value: 1, icon: "checkmark.seal.fill")
                        }

                        Button {
                            withAnimation(.snappy) {
                                selectedAnswer = nil
                                showingHint = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Next Card")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.50, blue: 0.98),
                                        Color(red: 0.20, green: 0.68, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color(red: 0.12, green: 0.50, blue: 0.98).opacity(0.35), radius: 8, y: 3)
                        }
                    }
                    .transition(.opacity)
                }

                // BOTTOM RIGHT: Continue in App button
                HStack {
                    Spacer()
                    Button {} label: {
                        HStack(spacing: 5) {
                            Text("Continue in App")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .foregroundStyle(isLight ? Color(red: 0.12, green: 0.48, blue: 0.96) : Color(red: 0.35, green: 0.70, blue: 1.0))
                        .canvasLiquidGlass(
                            cornerRadius: 10,
                            tint: isLight ? Color.white.opacity(0.65) : Color.white.opacity(0.08),
                            isLight: isLight
                        )
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(CanvasNotificationBackdrop(isLight: isLight))
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func optionTextColor(_ answer: String) -> Color {
        guard let selected = selectedAnswer else { return textColorPrimary }
        if answer == correctAnswer {
            return isLight ? Color(red: 0.05, green: 0.45, blue: 0.20) : Color.white
        }
        if answer == selected {
            return isLight ? Color(red: 0.70, green: 0.12, blue: 0.15) : Color.white
        }
        return textColorSecondary.opacity(0.6)
    }

    private func optionGlassTint(_ answer: String) -> Color? {
        guard let selected = selectedAnswer else {
            return isLight ? Color.white.opacity(0.65) : Color.white.opacity(0.08)
        }
        if answer == correctAnswer {
            return Color.green.opacity(isLight ? 0.22 : 0.32)
        }
        if answer == selected {
            return Color.red.opacity(isLight ? 0.20 : 0.30)
        }
        return isLight ? Color.white.opacity(0.35) : Color.white.opacity(0.04)
    }

    private func optionBorderColor(_ answer: String) -> Color? {
        guard let selected = selectedAnswer else { return nil }
        if answer == correctAnswer { return Color.green.opacity(0.85) }
        if answer == selected { return Color.red.opacity(0.85) }
        return nil
    }

    private func previewStat(_ title: String, value: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.98))
            Text("\(value)")
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(isLight ? Color(red: 0.10, green: 0.13, blue: 0.24) : Color.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isLight ? Color(red: 0.40, green: 0.45, blue: 0.58) : Color.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .canvasLiquidGlass(cornerRadius: 12, isLight: isLight)
    }
}

#Preview("Expanded Notification - Light") {
    NotificationCanvasView()
        .preferredColorScheme(.light)
        .frame(width: 393, height: 640)
}

#Preview("Expanded Notification - Dark") {
    NotificationCanvasView()
        .preferredColorScheme(.dark)
        .frame(width: 393, height: 640)
}
