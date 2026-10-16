import SwiftUI

/// The caller supplies two fitted faces and a fixed frame. Only the face facing
/// the reader is drawn, so neither picture becomes mirrored during the turn.
struct ImageCardFlipView<Front: View, Back: View>: View {
    @Binding var isShowingBack: Bool
    var isEnabled = true
    var onBackViewed: () -> Void = { }
    private let front: Front
    private let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0
    @State private var isTurning = false
    @State private var animationID = UUID()

    init(isShowingBack: Binding<Bool>, isEnabled: Bool = true,
         onBackViewed: @escaping () -> Void = { },
         @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        _isShowingBack = isShowingBack
        self.isEnabled = isEnabled
        self.onBackViewed = onBackViewed
        self.front = front()
        self.back = back()
    }

    var body: some View {
        Button {
            guard !isTurning else { return }
            isShowingBack.toggle()
        } label: {
            ZStack {
                if reduceMotion {
                    front.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isShowingBack ? 0 : 1)
                    back.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isShowingBack ? 1 : 0)
                } else {
                    front.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(ImageCardFlipFace(angle: angle))
                    back.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(ImageCardFlipFace(angle: angle - 180))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(reduceMotion ? .easeInOut(duration: 0.12) : nil, value: isShowingBack)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isTurning)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isShowingBack ? "Back image" : "Front image")
        .accessibilityHint(isShowingBack ? "Flip to the front image" : "Flip to the back image")
        .accessibilityAddTraits(.isImage)
        .onAppear {
            isTurning = false
            angle = isShowingBack ? 180 : 0
            if isShowingBack { onBackViewed() }
        }
        .onDisappear { animationID = UUID() }
        .onChange(of: isShowingBack) { _, showingBack in turn(showingBack) }
        .onChange(of: reduceMotion) { _, _ in
            animationID = UUID()
            isTurning = false
            angle = isShowingBack ? 180 : 0
            if isShowingBack { onBackViewed() }
        }
    }

    private func turn(_ showingBack: Bool) {
        let id = UUID()
        animationID = id
        if reduceMotion {
            isTurning = false
            angle = showingBack ? 180 : 0
            if showingBack { onBackViewed() }
            return
        }
        isTurning = true
        withAnimation(.smooth(duration: 0.52), completionCriteria: .logicallyComplete) {
            angle = showingBack ? 180 : 0
        } completion: {
            guard animationID == id else { return }
            isTurning = false
            if showingBack { onBackViewed() }
        }
    }
}

private struct ImageCardFlipFace: AnimatableModifier {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(abs(angle) < 90 ? 1 : 0)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }
}
