import Foundation

/// LearnAlert's deterministic, SM-2-inspired scheduler for imported Anki cards.
/// This is a local scheduler, not FSRS or a copy of Anki's scheduling engine.
nonisolated enum AnkiReviewRating: Int, Codable, CaseIterable, Identifiable {
    case again = 1, hard, good, easy

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
    var wasCorrect: Bool { self != .again }
}

nonisolated enum AnkiReviewPhase: String, Codable {
    case learning, relearning, review
}

nonisolated struct AnkiReviewRatingCounts: Codable, Equatable {
    var again = 0
    var hard = 0
    var good = 0
    var easy = 0

    init() {}
    private enum CodingKeys: String, CodingKey { case again, hard, good, easy }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        again = max(0, try values.decodeIfPresent(Int.self, forKey: .again) ?? 0)
        hard = max(0, try values.decodeIfPresent(Int.self, forKey: .hard) ?? 0)
        good = max(0, try values.decodeIfPresent(Int.self, forKey: .good) ?? 0)
        easy = max(0, try values.decodeIfPresent(Int.self, forKey: .easy) ?? 0)
    }

    var total: Int { again + hard + good + easy }
    func count(for rating: AnkiReviewRating) -> Int {
        switch rating {
        case .again: return again
        case .hard: return hard
        case .good: return good
        case .easy: return easy
        }
    }
    mutating func record(_ rating: AnkiReviewRating) {
        switch rating {
        case .again: again += 1
        case .hard: hard += 1
        case .good: good += 1
        case .easy: easy += 1
        }
    }
}

nonisolated struct AnkiReviewState: Codable, Equatable {
    var phase: AnkiReviewPhase = .learning
    var learningStep = 0
    var dueDate = Date.distantPast
    /// The delay selected at the most recent rating, including minute steps.
    var interval: TimeInterval = 0
    /// The mature interval to retain while completing a relearning step.
    var reviewInterval: TimeInterval = 86_400
    var easeFactor = 2.5
    var reviewCount = 0
    var lapses = 0
    var lastReviewedDate: Date? = nil
    var ratingCounts = AnkiReviewRatingCounts()
    var lastRating: AnkiReviewRating? = nil

    init() {}

    private enum CodingKeys: String, CodingKey {
        case phase, learningStep, dueDate, interval, reviewInterval, easeFactor
        case reviewCount, lapses, lastReviewedDate, ratingCounts, lastRating
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        phase = try values.decodeIfPresent(AnkiReviewPhase.self, forKey: .phase) ?? .learning
        learningStep = try values.decodeIfPresent(Int.self, forKey: .learningStep) ?? 0
        dueDate = try values.decodeIfPresent(Date.self, forKey: .dueDate) ?? .distantPast
        interval = try values.decodeIfPresent(TimeInterval.self, forKey: .interval) ?? 0
        reviewInterval = try values.decodeIfPresent(TimeInterval.self, forKey: .reviewInterval) ?? 86_400
        easeFactor = try values.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        reviewCount = try values.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        lapses = try values.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        lastReviewedDate = try values.decodeIfPresent(Date.self, forKey: .lastReviewedDate)
        ratingCounts = try values.decodeIfPresent(AnkiReviewRatingCounts.self, forKey: .ratingCounts) ?? .init()
        lastRating = try values.decodeIfPresent(AnkiReviewRating.self, forKey: .lastRating)
    }
}

nonisolated struct AnkiReviewOption: Identifiable, Equatable {
    let rating: AnkiReviewRating
    let interval: TimeInterval
    let nextReviewDate: Date
    let nextState: AnkiReviewState

    var id: Int { rating.id }
    var intervalLabel: String { AnkiReviewScheduling.intervalLabel(interval) }
    /// A short step remains pending; its dueDate controls when it is eligible.
    var shouldRepeatInSession: Bool { nextState.phase != .review }
}

nonisolated enum AnkiReviewScheduling {
    static let day: TimeInterval = 86_400
    static let minimumEase = 1.3
    static let maximumInterval: TimeInterval = 36_500 * day

    /// Old LearnAlert imports stored only aggregate scores and the last review.
    /// Keep their exact existing due date and totals without inventing ratings.
    static func migratingLegacy(reviewCount: Int, lastReviewedDate: Date?,
                                nextReviewDate: Date, interval: TimeInterval) -> AnkiReviewState {
        var state = AnkiReviewState()
        state.reviewCount = max(0, reviewCount)
        state.lastReviewedDate = lastReviewedDate
        guard reviewCount > 0 || lastReviewedDate != nil else { return state }
        state.phase = .review
        state.dueDate = nextReviewDate
        state.interval = max(0, interval)
        state.reviewInterval = boundedDays(max(day, interval))
        return state
    }

    static func options(for state: AnkiReviewState, at date: Date) -> [AnkiReviewOption] {
        AnkiReviewRating.allCases.map { option(for: $0, state: state, at: date) }
    }

    static func option(for rating: AnkiReviewRating, state: AnkiReviewState, at date: Date) -> AnkiReviewOption {
        var next = state
        next.easeFactor = state.easeFactor.isFinite ? max(minimumEase, state.easeFactor) : 2.5
        next.reviewInterval = boundedDays(state.reviewInterval)
        next.learningStep = min(1, max(0, state.learningStep))
        next.reviewCount = max(0, state.reviewCount) + 1
        next.lapses = max(0, state.lapses)
        next.lastReviewedDate = date
        next.lastRating = rating
        next.ratingCounts.record(rating)

        let delay: TimeInterval
        switch state.phase {
        case .learning:
            switch rating {
            case .again: next.learningStep = 0; delay = 60
            case .hard: delay = 6 * 60
            case .good:
                if next.learningStep == 0 { next.learningStep = 1; delay = 10 * 60 }
                else { next.phase = .review; delay = day }
            case .easy:
                next.phase = .review; next.easeFactor += 0.15; delay = 4 * day
            }
        case .relearning:
            switch rating {
            case .again: next.learningStep = 0; delay = 60
            case .hard: delay = 6 * 60
            case .good: next.phase = .review; delay = next.reviewInterval
            case .easy:
                next.phase = .review; next.easeFactor += 0.15
                delay = max(4 * day, boundedDays(next.reviewInterval * 1.3))
            }
        case .review:
            // Keep successful choices distinct even at a low ease or short interval.
            let previous = boundedDays(next.reviewInterval)
            let hard = boundedDays(max(previous + day, previous * 1.2))
            let good = boundedDays(max(hard + day, previous * next.easeFactor))
            let easy = boundedDays(max(good + day, previous * next.easeFactor * 1.3))
            switch rating {
            case .again:
                next.phase = .relearning; next.learningStep = 0
                next.lapses += 1; next.easeFactor = max(minimumEase, next.easeFactor - 0.2)
                next.reviewInterval = boundedDays(previous * 0.2); delay = 60
            case .hard:
                next.easeFactor = max(minimumEase, next.easeFactor - 0.15); delay = hard
            case .good: delay = good
            case .easy: next.easeFactor += 0.15; delay = easy
            }
        }
        next.interval = min(maximumInterval, delay)
        next.dueDate = date.addingTimeInterval(next.interval)
        if next.phase == .review { next.learningStep = 0; next.reviewInterval = next.interval }
        return AnkiReviewOption(rating: rating, interval: next.interval, nextReviewDate: next.dueDate, nextState: next)
    }

    static func intervalLabel(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval > 0 else { return "Now" }
        if interval < 3_600 { return "\(max(1, Int(ceil(interval / 60))))m" }
        if interval < day { return "\(Int(ceil(interval / 3_600)))h" }
        return "\(Int(ceil(interval / day)))d"
    }

    private static func boundedDays(_ interval: TimeInterval) -> TimeInterval {
        guard interval.isFinite else { return day }
        return min(maximumInterval, max(day, ceil(interval / day) * day))
    }
}
