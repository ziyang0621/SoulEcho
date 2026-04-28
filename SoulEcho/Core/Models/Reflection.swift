import Foundation

enum ReflectionState: String, Codable {
    case low
    case balanced
    case restored
    case unknown
}

struct ReflectionEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var dateKey: String
    var question: String
    var answer: String
    var checkIn: DailyCheckIn?
    var hrvValue: Double?
    var quoteContent: String?
    var quoteAuthor: String?
    var createdAt: Date
    var updatedAt: Date
}

enum CheckInChoice: String, Codable, CaseIterable {
    case a
    case b
    case c

    var score: Int {
        switch self {
        case .a: return 1
        case .b: return 2
        case .c: return 3
        }
    }
}

struct DailyCheckIn: Codable, Equatable {
    var physical: CheckInChoice?
    var mental: CheckInChoice?
    var emotional: CheckInChoice?

    var completedCount: Int {
        [physical, mental, emotional].compactMap { $0 }.count
    }

    var hasAnySelection: Bool {
        completedCount > 0
    }

    var isComplete: Bool {
        completedCount == 3
    }

    var averageScore: Double? {
        let scores = [physical, mental, emotional].compactMap { $0?.score }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
}
