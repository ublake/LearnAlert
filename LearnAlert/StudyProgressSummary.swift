import Foundation

/// A read-only aggregate of local decks and the shared course snapshot. Course
/// backing decks are transport copies, so their Flashcard counters are excluded.
@MainActor
struct StudyProgressSummary {
    struct DeckProgress: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let isCommunity: Bool
        let cardCount: Int
        let reviewedCardCount: Int
        let masteredCardCount: Int
        let masteryFraction: Double
    }

    struct CourseProgress: Identifiable {
        let id: String
        let title: String
        let flagEmoji: String
        let fraction: Double
        let currentStep: String
        let completedLessonCount: Int
        let lessonCount: Int
        let passedCheckpointCount: Int
        let checkpointCount: Int
    }

    let decks: [DeckProgress]
    let courses: [CourseProgress]
    let reviewCount: Int
    let cardCount: Int
    let reviewedCardCount: Int
    let masteredCardCount: Int
    let quizReviewCount: Int
    let quizCorrectCount: Int

    var learningCardCount: Int { max(0, reviewedCardCount - masteredCardCount) }
    var newCardCount: Int { max(0, cardCount - reviewedCardCount) }
    var quizAccuracy: Double? {
        quizReviewCount > 0 ? Double(quizCorrectCount) / Double(quizReviewCount) : nil
    }

    init(decks sourceDecks: [Deck], courses sourceCourses: [CourseDefinition], snapshot: CourseLearningSnapshot) {
        var seenDeckIDs = Set<UUID>()
        let ordinaryDecks = sourceDecks.filter { deck in
            guard deck.deckType.caseInsensitiveCompare("Course") != .orderedSame,
                  deck.sourcePremadeID?.hasPrefix("course:") != true else { return false }
            return seenDeckIDs.insert(deck.id).inserted
        }
        var seenCardIDs = Set<UUID>()
        let ordinaryCards = ordinaryDecks.flatMap(\.cards).filter { seenCardIDs.insert($0.id).inserted }
        var seenCourseIDs = Set<String>()
        let enrolledCourses = sourceCourses.filter { seenCourseIDs.insert($0.id).inserted }
        let courseCardIDs = Set(enrolledCourses.flatMap { $0.units.flatMap(\.lessons).flatMap(\.cards).map(\.id) })
        let courseSRS = courseCardIDs.compactMap { snapshot.srs[$0] }
        let reviewedCourseIDs = Set(courseCardIDs.filter { (snapshot.srs[$0]?.reviewCount ?? 0) > 0 || (snapshot.srs[$0]?.masteryScore ?? 0) > 0 })
            .union(enrolledCourses.flatMap { course in
                course.units.flatMap(\.lessons).flatMap { lesson in
                    Set(snapshot.progress[course.id]?[lesson.id]?.masteredCardIds ?? []).intersection(Set(lesson.cards.map(\.id)))
                }
            })

        self.decks = ordinaryDecks.map { deck in
            let cards = deck.cards
            return DeckProgress(id: deck.id, name: deck.name, colorHex: deck.colorHex,
                isCommunity: deck.sourceCommunityID != nil,
                cardCount: cards.count,
                reviewedCardCount: cards.filter { $0.reviewCount > 0 || $0.masteryScore > 0 }.count,
                masteredCardCount: cards.filter { $0.masteryScore >= 3 }.count,
                masteryFraction: Double(cards.reduce(0) { $0 + min(3, max(0, $1.masteryScore)) }) / Double(max(1, cards.count * 3)))
        }
        self.courses = enrolledCourses.map { course in
            let lessons = course.units.flatMap(\.lessons)
            let checkpoints = course.units.filter { $0.checkpointQuiz != nil }
            let currentStep: String
            if let pending = snapshot.pendingCheckpoint(course: course) {
                currentStep = pending.checkpointQuiz?.title ?? "Checkpoint ready"
            } else if let lesson = snapshot.currentLesson(course: course) {
                currentStep = lesson.title
            } else {
                currentStep = "Course complete"
            }
            return CourseProgress(id: course.id, title: course.title, flagEmoji: course.flagEmoji,
                fraction: snapshot.completionFraction(course: course), currentStep: currentStep,
                completedLessonCount: lessons.filter { snapshot.status(course: course, lessonId: $0.id) == .completed }.count,
                lessonCount: lessons.count,
                passedCheckpointCount: checkpoints.filter { snapshot.checkpoints[course.id]?[$0.id]?.passed == true }.count,
                checkpointCount: checkpoints.count)
        }
        reviewCount = ordinaryCards.reduce(0) { $0 + max(0, $1.reviewCount) }
            + courseSRS.reduce(0) { $0 + max(0, $1.reviewCount) }
        cardCount = ordinaryCards.count + courseCardIDs.count
        reviewedCardCount = ordinaryCards.filter { $0.reviewCount > 0 || $0.masteryScore > 0 }.count + reviewedCourseIDs.count
        masteredCardCount = ordinaryCards.filter { $0.masteryScore >= 3 }.count + courseSRS.filter { $0.masteryScore >= 3 }.count

        // Read-through and self-rated cards acknowledge study; they do not
        // provide an objective right/wrong quiz result.
        let quizCards = ordinaryCards.filter { [.multipleChoice, .matching, .fillBlank].contains($0.cardType) }
        quizReviewCount = quizCards.reduce(0) { $0 + max(0, $1.reviewCount) }
        quizCorrectCount = quizCards.reduce(0) { $0 + min(max(0, $1.correctCount), max(0, $1.reviewCount)) }
    }
}
