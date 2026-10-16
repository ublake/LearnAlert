import SwiftUI

/// Pair validation is independent of presentation order. A mistake can be corrected
/// immediately, but is still remembered when the exercise is graded.
struct CourseMatchingState {
    let pairCount: Int
    var selectedLeft: Int?
    var selectedRight: Int?
    var matched: Set<Int> = []
    var mistakeLeft: Int?
    var mistakeRight: Int?
    var hadMistake = false
    var complete: Bool { pairCount > 0 && matched.count == pairCount }

    init(pairCount: Int) {
        self.pairCount = max(0, pairCount)
    }

    /// Only shuffle pairs that exist on both sides. Shuffling all right-hand
    /// items before taking a prefix can hide a required match in malformed data.
    static func rightOrder(pairCount: Int) -> [Int] {
        let indices = Array(0..<max(0, pairCount))
        let shuffled = indices.shuffled()
        guard shuffled.count > 1, shuffled == indices else { return shuffled }
        return Array(shuffled.dropFirst()) + [shuffled[0]]
    }

    mutating func select(_ index: Int, left: Bool) {
        guard (0..<pairCount).contains(index), !matched.contains(index), !complete else { return }
        mistakeLeft = nil; mistakeRight = nil
        if left { selectedLeft = selectedLeft == index ? nil : index }
        else { selectedRight = selectedRight == index ? nil : index }
        guard let lhs = selectedLeft, let rhs = selectedRight else { return }
        if lhs == rhs { matched.insert(lhs) }
        else { hadMistake = true; mistakeLeft = lhs; mistakeRight = rhs }
        selectedLeft = nil; selectedRight = nil
    }
}

struct CourseMatchingPanel: View {
    let card: CourseLessonCard
    let immersive: Bool
    let onAnswer: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var state: CourseMatchingState
    @State private var rightOrder: [Int]
    @State private var submitted = false
    private let pairColors: [Color] = [.teal, .orange, .indigo, .pink, .green, .blue]

    init(card: CourseLessonCard, immersive: Bool, onAnswer: @escaping (Bool) -> Void) {
        self.card = card; self.immersive = immersive; self.onAnswer = onAnswer
        let count = min(card.matchingLeftItems.count, card.matchingRightItems.count)
        _state = State(initialValue: CourseMatchingState(pairCount: count))
        _rightOrder = State(initialValue: CourseMatchingState.rightOrder(pairCount: count))
    }

    var body: some View {
        VStack(spacing: immersive ? 20 : 12) {
            HStack {
                Label(statusText, systemImage: statusIcon)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("\(state.matched.count) / \(state.pairCount)")
                    .monospacedDigit().font(.subheadline.weight(.semibold))
                    .accessibilityLabel("\(state.matched.count) of \(state.pairCount) pairs matched")
            }.foregroundStyle(state.mistakeLeft == nil ? Color.secondary : .orange)
            if state.pairCount == 0 {
                Text("This matching activity has no pairs.").font(.callout).foregroundStyle(.secondary)
                Button("Continue") {
                    guard !submitted else { return }
                    submitted = true
                    onAnswer(false)
                }.buttonStyle(.borderedProminent)
            } else if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Items").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(0..<state.pairCount, id: \.self) { index in
                        tile(index, left: true).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Matches").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 8)
                    ForEach(rightOrder, id: \.self) { index in
                        tile(index, left: false).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                VStack(spacing: immersive ? 16 : 8) {
                    HStack(spacing: immersive ? 16 : 8) {
                        Text("Items").frame(maxWidth: .infinity)
                        Text("Matches").frame(maxWidth: .infinity)
                    }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(0..<state.pairCount, id: \.self) { row in
                        HStack(spacing: immersive ? 16 : 8) {
                            tile(row, left: true)
                            tile(rightOrder[row], left: false)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: state.selectedLeft)
        .sensoryFeedback(.selection, trigger: state.selectedRight)
        .sensoryFeedback(.success, trigger: state.matched.count)
        .sensoryFeedback(.error, trigger: state.mistakeRight)
        .onChange(of: card) { _, newCard in
            let count = min(newCard.matchingLeftItems.count, newCard.matchingRightItems.count)
            state = CourseMatchingState(pairCount: count)
            rightOrder = CourseMatchingState.rightOrder(pairCount: count)
            submitted = false
        }
        .onChange(of: state.complete) { _, complete in
            if complete && !submitted { submitted = true; onAnswer(!state.hadMistake) }
        }
    }

    private var statusText: String {
        if state.complete { return "All pairs matched" }
        if state.mistakeLeft != nil { return "Not a pair. Try again." }
        if state.selectedLeft != nil || state.selectedRight != nil { return "Choose from the other side" }
        return "Tap one item, then its match"
    }

    private var statusIcon: String {
        if state.complete { return "checkmark.circle.fill" }
        if state.mistakeLeft != nil { return "arrow.counterclockwise" }
        return "hand.tap"
    }

    private func tile(_ index: Int, left: Bool) -> some View {
        let selected = (left ? state.selectedLeft : state.selectedRight) == index
        let wrong = (left ? state.mistakeLeft : state.mistakeRight) == index
        let matched = state.matched.contains(index)
        let color: Color = wrong ? .orange : selected ? .accentColor : matched ? pairColors[index % pairColors.count] : .primary
        let border: Color = selected || wrong || matched
            ? color.opacity(selected || wrong ? 0.9 : 0.55)
            : colorScheme == .light ? CourseSurfaceStyle.lightOutline : color.opacity(0.12)
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) { state.select(index, left: left) }
        } label: {
            HStack(spacing: 8) {
                Text(left ? card.matchingLeftItems[index] : card.matchingRightItems[index])
                    .font(immersive ? .title3.weight(.semibold) : .body.weight(.medium))
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Image(systemName: matched ? "checkmark.circle.fill" : wrong ? "xmark.circle" : selected ? "circle.inset.filled" : "circle")
                    .font(.caption.bold()).foregroundStyle(color.opacity(matched || selected || wrong ? 1 : 0.3))
                    .accessibilityHidden(true)
            }.foregroundStyle(.primary).padding(.horizontal, 12).padding(.vertical, immersive ? 20 : 12)
                .frame(maxWidth: .infinity, minHeight: immersive ? 80 : 56)
                .background(color.opacity(selected ? 0.22 : matched || wrong ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: immersive ? 20 : 12))
                .overlay(RoundedRectangle(cornerRadius: immersive ? 20 : 12).stroke(border, lineWidth: selected ? 3 : 1.5))
                .scaleEffect(selected ? 1.025 : 1)
        }.buttonStyle(.plain).disabled(matched || state.complete)
            .accessibilityLabel("\(left ? "Item" : "Match"): \(left ? card.matchingLeftItems[index] : card.matchingRightItems[index])")
            .accessibilityValue(matched ? "Matched" : selected ? "Selected" : wrong ? "Try again" : "")
            .accessibilityHint(matched ? "" : selected ? "Double-tap to deselect, or choose its match from the other side." : "Select this item, then choose its match from the other side.")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
