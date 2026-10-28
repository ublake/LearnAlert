import SwiftUI

enum TutorialCoachTarget: Hashable {
    case firstDeck, deckBack, homeSchedule
}

struct TutorialCoachStep: Hashable {
    let target: TutorialCoachTarget
    let title: String
    let message: String
}

private struct TutorialCoachAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialCoachTarget: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [TutorialCoachTarget: Anchor<CGRect>],
                       nextValue: () -> [TutorialCoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func tutorialCoachTarget(_ target: TutorialCoachTarget) -> some View {
        anchorPreference(key: TutorialCoachAnchorKey.self, value: .bounds) { [target: $0] }
    }

    func tutorialCoach(steps: [TutorialCoachStep], activeIndex: Binding<Int?>,
                       globalTargets: [TutorialCoachTarget: CGRect] = [:]) -> some View {
        overlayPreferenceValue(TutorialCoachAnchorKey.self) { anchors in
            TutorialCoachOverlay(steps: steps, activeIndex: activeIndex, anchors: anchors,
                                 globalTargets: globalTargets)
        }
    }
}

/// One passive callout per tour step, with a short pause before it appears.
struct TutorialCoachOverlay: View {
    let steps: [TutorialCoachStep]
    @Binding var activeIndex: Int?
    private let anchors: [TutorialCoachTarget: Anchor<CGRect>]
    private let globalTargets: [TutorialCoachTarget: CGRect]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sequenceGeneration = UUID()

    fileprivate init(steps: [TutorialCoachStep], activeIndex: Binding<Int?>,
                     anchors: [TutorialCoachTarget: Anchor<CGRect>],
                     globalTargets: [TutorialCoachTarget: CGRect]) {
        self.steps = steps
        _activeIndex = activeIndex
        self.anchors = anchors
        self.globalTargets = globalTargets
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let index = activeIndex, steps.indices.contains(index),
                   let target = resolvedTarget(steps[index].target, in: proxy) {
                    TutorialCoachScene(step: steps[index], target: target, canvas: proxy.size)
                        .id(steps[index])
                        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .task(id: steps) {
            let generation = UUID()
            sequenceGeneration = generation
            activeIndex = nil
            guard !steps.isEmpty else { return }
            do {
                try await Task.sleep(for: .seconds(1))
                try Task.checkCancellation()
                guard sequenceGeneration == generation else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)) {
                    activeIndex = 0
                }
            } catch is CancellationError {
                // Leaving the page cancels the entrance before it can show.
            } catch { }
        }
        .onDisappear {
            sequenceGeneration = UUID()
            activeIndex = nil
        }
    }

    private func resolvedTarget(_ target: TutorialCoachTarget, in proxy: GeometryProxy) -> CGRect? {
        if let frame = globalTargets[target], !frame.isNull, !frame.isEmpty {
            let origin = proxy.frame(in: .global).origin
            return frame.offsetBy(dx: -origin.x, dy: -origin.y)
        }
        return anchors[target].map { proxy[$0] }
    }
}

private struct TutorialCoachBubbleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TutorialCoachScene: View {
    let step: TutorialCoachStep
    let target: CGRect
    let canvas: CGSize
    @Environment(\.colorScheme) private var pageColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bubbleHeight: CGFloat = 112
    @State private var arrowProgress: CGFloat = 0

    // Explicit colors keep the inverse appearance reliable for System Default too.
    private var bubbleScheme: ColorScheme { pageColorScheme == .dark ? .light : .dark }
    private var bubbleSurface: Color {
        pageColorScheme == .dark ? .white : Color(red: 0.14, green: 0.15, blue: 0.18)
    }
    private var bubbleTitle: Color {
        pageColorScheme == .dark ? Color(red: 0.15, green: 0.18, blue: 0.21)
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }
    private var bubbleText: Color {
        pageColorScheme == .dark ? Color(red: 0.39, green: 0.43, blue: 0.47)
            : Color(red: 0.76, green: 0.79, blue: 0.84)
    }
    private var bubbleBorder: Color {
        pageColorScheme == .dark ? Color(red: 0.22, green: 0.40, blue: 0.56).opacity(0.35)
            : Color(red: 0.66, green: 0.83, blue: 0.97).opacity(0.45)
    }

    private var bubbleWidth: CGFloat { min(292, max(1, canvas.width - 32)) }
    private var showsBelow: Bool {
        let below = canvas.height - target.maxY - 16
        let above = target.minY - 16
        return below >= bubbleHeight + 54 || below >= above
    }
    private var bubbleCenter: CGPoint {
        let halfWidth = bubbleWidth / 2
        let preferredX = step.target == .deckBack
            ? target.midX + (target.midX > canvas.width / 2 ? -108 : 108) : target.midX
        let x = min(max(preferredX, 16 + halfWidth), max(16 + halfWidth, canvas.width - 16 - halfWidth))
        let preferredY = step.target == .deckBack ? arrowEnd.y + 54 + bubbleHeight / 2
            : showsBelow ? target.maxY + 54 + bubbleHeight / 2 : target.minY - 54 - bubbleHeight / 2
        let minY = 16 + bubbleHeight / 2
        let maxY = max(minY, canvas.height - 16 - bubbleHeight / 2)
        return CGPoint(x: x, y: min(max(preferredY, minY), maxY))
    }
    private var arrowStart: CGPoint {
        CGPoint(x: bubbleCenter.x + (step.target == .deckBack ? (target.midX > canvas.width / 2 ? 44 : -44) : 24),
                y: bubbleCenter.y + (showsBelow ? -bubbleHeight / 2 - 8 : bubbleHeight / 2 + 8))
    }
    private var arrowEnd: CGPoint {
        let x = target.midX
        let y = step.target == .deckBack ? target.maxY + 6 : (showsBelow ? target.maxY + 6 : target.minY - 6)
        return CGPoint(x: min(max(x, 8), canvas.width - 8),
                       y: min(max(y, 5), canvas.height - 5))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let bend: CGFloat = reduceMotion ? 0 : CGFloat(sin(timeline.date.timeIntervalSinceReferenceDate * 2.2) * 3)
                let arrow = TutorialCoachArrow(start: arrowStart, end: arrowEnd, bend: bend,
                    aim: step.target == .deckBack ? CGPoint(x: target.midX, y: target.midY) : nil)
                    .trim(from: 0, to: arrowProgress)
                ZStack {
                    arrow.stroke(pageColorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    arrow.stroke(LearnAlertStyle.appAccentForeground,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .callout))
                    .foregroundStyle(bubbleTitle)
                Text(step.message)
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(bubbleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: bubbleWidth, alignment: .leading)
            .background(bubbleSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(bubbleBorder, lineWidth: 1.2)
            }
            .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
            .environment(\.colorScheme, bubbleScheme)
            .background {
                GeometryReader { bubble in
                    Color.clear.preference(key: TutorialCoachBubbleHeightKey.self, value: bubble.size.height)
                }
            }
            .position(bubbleCenter)
            .accessibilityElement(children: .combine)
        }
        .frame(width: canvas.width, height: canvas.height)
        .onPreferenceChange(TutorialCoachBubbleHeightKey.self) { height in
            if height > 0 && abs(bubbleHeight - height) > 0.5 { bubbleHeight = height }
        }
        .onAppear {
            if reduceMotion { arrowProgress = 1 }
            else { withAnimation(.easeOut(duration: 0.55)) { arrowProgress = 1 } }
        }
    }
}

private struct TutorialCoachArrow: Shape {
    let start: CGPoint
    let end: CGPoint
    let bend: CGFloat
    var aim: CGPoint? = nil

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let direction: CGFloat = end.y > start.y ? 1 : -1
        let travel = max(18, abs(end.y - start.y) * 0.55)
        let control1 = CGPoint(x: start.x - 20 + bend, y: start.y + travel * direction)
        let control2: CGPoint
        if let aim {
            let dx = aim.x - end.x, dy = aim.y - end.y
            let distance = max(1, hypot(dx, dy))
            control2 = CGPoint(x: end.x - dx / distance * travel, y: end.y - dy / distance * travel)
        } else {
            control2 = CGPoint(x: end.x + 16 + bend, y: end.y - travel * direction)
        }
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)

        let angle = atan2(end.y - control2.y, end.x - control2.x)
        for wing in [-CGFloat.pi / 5, CGFloat.pi / 5] {
            path.move(to: CGPoint(x: end.x - 10 * cos(angle + wing), y: end.y - 10 * sin(angle + wing)))
            path.addQuadCurve(to: end, control: CGPoint(x: end.x - 4 * cos(angle + wing), y: end.y - 4 * sin(angle + wing)))
        }
        return path
    }
}
