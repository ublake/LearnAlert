import SwiftUI

/// Canvas-friendly stand-in for the notification content extension.
///
/// Xcode can't host previews inside a notification content extension, so this
/// view lives in the app target and mirrors the extension's expanded layout.
struct NotificationCanvasView: View {
    @State private var selectedAnswer: String?
    @State private var showingHint = false
    @State private var showingControls = false

    private let answers = ["Good night", "Good morning", "Good afternoon", "Goodbye"]
    private let correctAnswer = "Good morning"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.snappy) {
                            showingControls.toggle()
                        }
                    } label: {
                        Image(systemName: showingControls ? "xmark" : "gearshape.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                }

                if showingControls {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notification controls", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        Label("Change mini-session deck", systemImage: "rectangle.stack.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Label("Stop scheduled notifications", systemImage: "bell.slash.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Text("What does “Buenos días” mean?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    ForEach(answers, id: \.self) { answer in
                        Button {
                            guard selectedAnswer == nil else { return }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedAnswer = answer
                            }
                        } label: {
                            Text(answer)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(answerBackground(answer))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(answerBorder(answer), lineWidth: 1.5)
                                )
                        }
                    }
                }

                if selectedAnswer == nil {
                    HStack(spacing: 15) {
                        Button {
                            withAnimation(.spring) {
                                showingHint.toggle()
                            }
                        } label: {
                            Label(showingHint ? "Hide Hint" : "Hint", systemImage: "lightbulb.fill")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: {}) {
                            Label("Skip", systemImage: "forward.fill")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.15))
                                .foregroundStyle(.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                if showingHint {
                    Text("This greeting is commonly used before noon.")
                        .font(.subheadline.italic())
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if selectedAnswer != nil {
                    HStack(spacing: 10) {
                        previewStat("New", value: 5, icon: "sparkles")
                        previewStat("Learning", value: 2, icon: "brain.head.profile")
                        previewStat("Mastered", value: 1, icon: "checkmark.seal.fill")
                    }

                    Button("Reset Preview") {
                        withAnimation(.snappy) {
                            selectedAnswer = nil
                            showingHint = false
                        }
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, minHeight: 500, alignment: .top)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }

    private func answerBackground(_ answer: String) -> Color {
        guard let selectedAnswer else { return Color.white.opacity(0.08) }
        if answer == correctAnswer { return Color.green.opacity(0.25) }
        if answer == selectedAnswer { return Color.red.opacity(0.25) }
        return Color.white.opacity(0.03)
    }

    private func answerBorder(_ answer: String) -> Color {
        guard let selectedAnswer else { return .clear }
        if answer == correctAnswer { return Color.green.opacity(0.8) }
        if answer == selectedAnswer { return Color.red.opacity(0.8) }
        return .clear
    }

    private func previewStat(_ title: String, value: Int, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Expanded Notification") {
    NotificationCanvasView()
        .frame(width: 393, height: 620)
}
