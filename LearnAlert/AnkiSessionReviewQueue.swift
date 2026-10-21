import Foundation

/// Short learning steps stay pending until their advertised review time. Closing
/// a session is safe: the authoritative due date lives on the persisted card.
struct AnkiSessionReviewQueue {
    private(set) var pending: [UUID: Date] = [:]

    var nextDate: Date? { pending.values.min() }

    mutating func schedule(_ id: UUID, due: Date, repeatsInSession: Bool) {
        if repeatsInSession { pending[id] = due }
        else { pending.removeValue(forKey: id) }
    }

    mutating func takeReady(at now: Date, reviewEarly: Bool = false) -> [UUID] {
        let ordered = pending.sorted {
            $0.value == $1.value ? $0.key.uuidString < $1.key.uuidString : $0.value < $1.value
        }
        let ready = reviewEarly ? Array(ordered.prefix(1)) : ordered.filter { $0.value <= now }
        for item in ready { pending.removeValue(forKey: item.key) }
        return ready.map(\.key)
    }
}
