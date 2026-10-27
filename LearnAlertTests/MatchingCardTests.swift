import Testing
@testable import LearnAlert

@MainActor
@Suite("Matching cards")
struct MatchingCardTests {
    @Test("Matching orders include every valid pair and no unmatched extra item")
    func validPairOrder() {
        let left = ["ㅏ", "ㅓ"]
        let right = ["ah", "eo", "unused"]
        let count = min(left.count, right.count)
        for _ in 0..<40 {
            let order = MatchingCardState.rightOrder(pairCount: count)
            #expect(order.count == count)
            #expect(Set(order) == Set(0..<count))
            var state = MatchingCardState(pairCount: count)
            for index in order {
                state.select(index, left: false)
                state.select(index, left: true)
            }
            #expect(state.complete && !state.hadMistake)
        }
    }

    @Test("Empty and invalid pair counts stay inert")
    func emptyPairs() {
        for count in [-1, 0] {
            var state = MatchingCardState(pairCount: count)
            state.select(0, left: true)
            state.select(0, left: false)
            #expect(!state.complete && state.matched.isEmpty)
            #expect(state.selectedLeft == nil && state.selectedRight == nil)
            #expect(MatchingCardState.rightOrder(pairCount: count).isEmpty)
        }
        #expect(MatchingCardState.rightOrder(pairCount: 1) == [0])
    }

    @Test("Incorrect pairs clear both selections and remain incorrect after correction")
    func correctedMistake() {
        var state = MatchingCardState(pairCount: 2)
        state.select(0, left: false)
        state.select(1, left: true)
        #expect(state.mistakeLeft == 1 && state.mistakeRight == 0)
        #expect(state.selectedLeft == nil && state.selectedRight == nil)
        #expect(state.hadMistake && state.matched.isEmpty)

        state.select(1, left: true)
        #expect(state.mistakeLeft == nil && state.mistakeRight == nil)
        state.select(1, left: false)
        state.select(0, left: true)
        state.select(0, left: false)
        #expect(state.complete && state.hadMistake)

        state.select(1, left: false)
        state.select(-1, left: true)
        state.select(2, left: false)
        #expect(state.selectedLeft == nil && state.selectedRight == nil)
        #expect(state.matched == [0, 1])
    }
}
