import SwiftUI

enum TutorialCoachTarget: Hashable {
    case deckTools, deckBack, homeLibrary, homeSchedule
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

    func tutorialCoach(steps: [TutorialCoachStep], activeIndex: Binding<Int?>) -> some View {
        overlayPreferenceValue(TutorialCoachAnchorKey.self) { anchors in
            TutorialCoachOverlay(steps: steps, activeIndex: activeIndex, anchors: anchors)
        }
    }
}

/// A passive, view-scoped tour: no timers survive navigation or skipping the tour.
struct TutorialCoachOverlay: View {
    let steps: [TutorialCoachStep]
    @Binding var activeIndex: Int?
    private let anchors: [TutorialCoachTarget: Anchor<CGRect>]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sequenceGeneration = UUID()

    fileprivate init(steps: [TutorialCoachStep], activeIndex: Binding<Int?>,
                     anchors: [TutorialCoachTarget: Anchor<CGRect>]) {
        self.steps = steps
        _activeIndex = activeIndex
        self.anchors = anchors
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let index = activeIndex, steps.indices.contains(index),
                   let anchor = anchors[steps[index].target] {
                    TutorialCoachScene(step: steps[index], index: index, count: steps.count,
                                       target: proxy[anchor], canvas: proxy.size)
                        .id(index)
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
                var index = 0
                while !Task.isCancelled && sequenceGeneration == generation {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)) {
                        activeIndex = index
                    }
                    try await Task.sleep(for: .seconds(5))
                    try Task.checkCancellation()
                    index = (index + 1) % steps.count
                }
            } catch is CancellationError {
                // Leaving the page cancels both the initial pause and the cycle.
            } catch { }
        }
        .onDisappear {
            sequenceGeneration = UUID()
            activeIndex = nil
        }
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
    let index: Int
    let count: Int
    let target: CGRect
    let canvas: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bubbleHeight: CGFloat = 112
    @State private var arrowProgress: CGFloat = 0

    private var bubbleWidth: CGFloat { min(292, max(1, canvas.width - 32)) }
    private var showsBelow: Bool {
        let below = canvas.height - target.maxY - 16
        let above = target.minY - 16
        return below >= bubbleHeight + 54 || below >= above
    }
    private var bubbleCenter: CGPoint {
        let halfWidth = bubbleWidth / 2
        let preferredX = step.target == .deckBack ? target.minX + 130 : target.midX
        let x = min(max(preferredX, 16 + halfWidth), max(16 + halfWidth, canvas.width - 16 - halfWidth))
        let preferredY = showsBelow ? target.maxY + 54 + bubbleHeight / 2 : target.minY - 54 - bubbleHeight / 2
        let minY = 16 + bubbleHeight / 2
        let maxY = max(minY, canvas.height - 16 - bubbleHeight / 2)
        return CGPoint(x: x, y: min(max(preferredY, minY), maxY))
    }
    private var arrowStart: CGPoint {
        CGPoint(x: bubbleCenter.x + (step.target == .deckBack ? -44 : 24),
                y: bubbleCenter.y + (showsBelow ? -bubbleHeight / 2 - 8 : bubbleHeight / 2 + 8))
    }
    private var arrowEnd: CGPoint {
        let x = step.target == .deckBack ? target.minX + min(22, target.width / 2) : target.midX
        let y = step.target == .deckBack ? target.midY : (showsBelow ? target.maxY + 6 : target.minY - 6)
        return CGPoint(x: min(max(x, 8), canvas.width - 8),
                       y: min(max(y, 5), canvas.height - 5))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let bend: CGFloat = reduceMotion ? 0 : CGFloat(sin(timeline.date.timeIntervalSinceReferenceDate * 2.2) * 3)
                TutorialCoachArrow(start: arrowStart, end: arrowEnd, bend: bend)
                    .trim(from: 0, to: arrowProgress)
                    .stroke(LearnAlertStyle.appAccentForeground,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: LearnAlertStyle.courseSurface.opacity(0.9), radius: 2)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(step.title)
                        .font(.custom("Poppins-SemiBold", size: 14, relativeTo: .callout))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        ForEach(0..<count, id: \.self) { item in
                            Capsule().fill(LearnAlertStyle.appAccentForeground.opacity(item == index ? 0.85 : 0.2))
                                .frame(width: item == index ? 10 : 4, height: 4)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Text(step.message)
                    .font(.custom("Poppins-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(LearnAlertStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: bubbleWidth, alignment: .leading)
            .background(LearnAlertStyle.courseSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LearnAlertStyle.appAccentForeground.opacity(0.35), lineWidth: 1.2)
            }
            .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
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

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let direction: CGFloat = end.y > start.y ? 1 : -1
        let travel = max(18, abs(end.y - start.y) * 0.55)
        let control1 = CGPoint(x: start.x - 20 + bend, y: start.y + travel * direction)
        let control2 = CGPoint(x: end.x + 16 + bend, y: end.y - travel * direction)
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
