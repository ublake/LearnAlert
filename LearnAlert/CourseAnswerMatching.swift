import Foundation

extension CourseLessonCard {
    func accepts(_ answer: String) -> Bool {
        func normalize(_ value: String) -> String {
            value.precomposedStringWithCanonicalMapping.lowercased().unicodeScalars
                .filter { !CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).contains($0) }
                .map(String.init).joined()
        }
        let candidates = [correctAnswer] + (acceptedAnswers ?? [])
        return !normalize(answer).isEmpty && candidates.contains { normalize($0) == normalize(answer) }
    }
}
