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
        _state = State(initialValue: CourseMatchingState(pairCount: min(card.matchingLeftItems.count, card.matchingRightItems.count)))
        _rightOrder = State(initialValue: Array(card.matchingRightItems.indices).shuffled())
    }

    var body: some View {
        VStack(spacing: immersive ? 24 : 12) {
            HStack {
                Text(state.mistakeLeft == nil ? "Tap a pair" : "Try another pair").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(state.matched.count) / \(state.pairCount)").monospacedDigit().font(.subheadline.weight(.semibold))
            }.foregroundStyle(state.mistakeLeft == nil ? Color.secondary : .orange)
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Words").font(.headline)
                    ForEach(0..<state.pairCount, id: \.self) { index in
                        tile(index, left: true).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Matches").font(.headline).padding(.top, 8)
                    ForEach(Array(rightOrder.prefix(state.pairCount)), id: \.self) { index in
                        tile(index, left: false).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                VStack(spacing: immersive ? 16 : 8) {
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
        .onChange(of: state.complete) { _, complete in
            if complete && !submitted { submitted = true; onAnswer(!state.hadMistake) }
        }
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
                if matched { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(color) }
            }.foregroundStyle(.primary).padding(.horizontal, 12).padding(.vertical, immersive ? 20 : 12)
                .frame(maxWidth: .infinity, minHeight: immersive ? 80 : 56, maxHeight: .infinity)
                .background(color.opacity(selected ? 0.22 : matched || wrong ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: immersive ? 20 : 12))
                .overlay(RoundedRectangle(cornerRadius: immersive ? 20 : 12).stroke(border, lineWidth: selected ? 3 : 1.5))
                .scaleEffect(selected ? 1.025 : 1)
        }.buttonStyle(.plain).disabled(matched || state.complete)
            .accessibilityLabel(left ? card.matchingLeftItems[index] : card.matchingRightItems[index])
            .accessibilityValue(matched ? "Matched" : selected ? "Selected" : wrong ? "Try again" : "")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
