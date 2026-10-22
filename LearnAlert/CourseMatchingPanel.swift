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
    @Environment(\.courseNotificationCompact) private var notificationCompact
    private var compact: Bool { notificationCompact && !immersive }
    @State private var state: CourseMatchingState
    @State private var rightOrder: [Int]
    @State private var submitted = false

    init(card: CourseLessonCard, immersive: Bool, onAnswer: @escaping (Bool) -> Void) {
        self.card = card; self.immersive = immersive; self.onAnswer = onAnswer
        let count = min(card.matchingLeftItems.count, card.matchingRightItems.count)
        _state = State(initialValue: CourseMatchingState(pairCount: count))
        _rightOrder = State(initialValue: CourseMatchingState.rightOrder(pairCount: count))
    }

    var body: some View {
        CardMediaMatchingBoard(left: card.matchingLeftItems, right: card.matchingRightItems,
            fields: card.resolvedFieldMedia, isGraded: submitted) { correct in
                guard !submitted else { return }
                submitted = true; onAnswer(correct)
            }
    }

}
