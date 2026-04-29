import Foundation
import Observation

@Observable
final class ReflectionService {
    var currentQuestion = ""
    var currentState: ReflectionState = .unknown
    var draftAnswer = ""
    var checkIn = DailyCheckIn()
    var todayEntry: ReflectionEntry?
    private(set) var entries: [ReflectionEntry] = []

    private let storageKey = "reflection_entries"
    private let groupIdentifier = "group.com.ziyang.SoulEcho"
    private let watchCheckInKey = "watch_quick_checkin"

    init() {
        entries = loadEntries()
        todayEntry = entries.first { $0.dateKey == Self.dateKey(for: Date()) }
        draftAnswer = todayEntry?.answer ?? ""
        checkIn = todayEntry?.checkIn ?? DailyCheckIn()
        refreshQuestion(hrvValue: nil)
        mergeWatchCheckIn()
    }

    /// Reads Watch quick check-in from App Group and merges it into today's reflection.
    /// Watch data always overwrites iPhone check-in since it is newer.
    func mergeWatchCheckIn() {
        guard let groupDefaults = UserDefaults(suiteName: groupIdentifier),
              let data = groupDefaults.data(forKey: watchCheckInKey) else { return }

        struct WatchRecord: Codable {
            let dateKey: String
            let physical: Int
            let mental: Int
            let emotional: Int
            let timestamp: Date
        }

        guard let record = try? JSONDecoder().decode(WatchRecord.self, from: data),
              record.dateKey == Self.dateKey(for: Date()) else { return }

        // Skip if we already merged this exact Watch record
        let mergedKey = "last_merged_watch_checkin_ts"
        let lastMergedTs = groupDefaults.double(forKey: mergedKey)
        let recordTs = record.timestamp.timeIntervalSince1970
        guard recordTs > lastMergedTs else { return }

        func toChoice(_ score: Int) -> CheckInChoice? {
            switch score {
            case 1: return .a
            case 2: return .b
            case 3: return .c
            default: return nil
            }
        }

        // Always overwrite with Watch data
        if let c = toChoice(record.physical) { checkIn.physical = c }
        if let c = toChoice(record.mental) { checkIn.mental = c }
        if let c = toChoice(record.emotional) { checkIn.emotional = c }

        // Update or create today's entry
        if let existing = todayEntry {
            let updated = ReflectionEntry(
                id: existing.id,
                dateKey: existing.dateKey,
                question: existing.question,
                answer: existing.answer,
                checkIn: checkIn,
                hrvValue: existing.hrvValue,
                quoteContent: existing.quoteContent,
                quoteAuthor: existing.quoteAuthor,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
            entries.removeAll { $0.dateKey == existing.dateKey }
            entries.insert(updated, at: 0)
            todayEntry = updated
            persistEntries()
        }

        // Mark this record as merged so we don't repeat
        groupDefaults.set(recordTs, forKey: mergedKey)

        print("[iPhone] ✅ Merged Watch check-in: P=\(record.physical) M=\(record.mental) E=\(record.emotional)")
    }

    func refreshQuestion(hrvValue: Double?) {
        if let todayEntry {
            currentQuestion = todayEntry.question
            currentState = Self.state(for: todayEntry.hrvValue)
            return
        }

        currentState = Self.state(for: hrvValue)
        currentQuestion = Self.question(for: currentState, on: Date())
    }

    func syncTodayHRV(_ hrvValue: Double?) {
        guard let hrvValue, let existing = todayEntry else { return }
        guard existing.hrvValue == nil || abs((existing.hrvValue ?? 0) - hrvValue) >= 0.1 else { return }

        let entry = ReflectionEntry(
            id: existing.id,
            dateKey: existing.dateKey,
            question: existing.question,
            answer: existing.answer,
            checkIn: existing.checkIn,
            hrvValue: hrvValue,
            quoteContent: existing.quoteContent,
            quoteAuthor: existing.quoteAuthor,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        entries.removeAll { $0.id == existing.id || $0.dateKey == existing.dateKey }
        entries.insert(entry, at: 0)
        todayEntry = entry
        currentState = Self.state(for: hrvValue)
        persistEntries()
    }

    @discardableResult
    func saveTodayAnswer(hrvValue: Double?, quote: Quote?) -> Bool {
        let trimmedAnswer = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty || checkIn.hasAnySelection else { return false }

        let now = Date()
        let dateKey = Self.dateKey(for: now)
        let existing = entries.first { $0.dateKey == dateKey }
        let savedCheckIn = checkIn.hasAnySelection ? checkIn : existing?.checkIn

        let entry = ReflectionEntry(
            id: existing?.id ?? UUID(),
            dateKey: dateKey,
            question: existing?.question ?? currentQuestion,
            answer: trimmedAnswer,
            checkIn: savedCheckIn,
            hrvValue: hrvValue ?? existing?.hrvValue,
            quoteContent: quote?.content ?? existing?.quoteContent,
            quoteAuthor: quote?.author ?? existing?.quoteAuthor,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        entries.removeAll { $0.dateKey == dateKey }
        entries.insert(entry, at: 0)
        if entries.count > 90 {
            entries = Array(entries.prefix(90))
        }

        todayEntry = entry
        currentQuestion = entry.question
        persistEntries()
        return true
    }

    var hasSavedToday: Bool {
        todayEntry != nil
    }

    var hasEntries: Bool {
        !entries.isEmpty
    }

    var stateLabel: String {
        switch currentState {
        case .low:
            return isChinese ? "身体在提醒你慢一点" : "Your body is asking for softness"
        case .balanced:
            return isChinese ? "今天适合温柔校准" : "A gentle check-in fits today"
        case .restored:
            return isChinese ? "把稳定感记下来" : "Notice what feels steady"
        case .unknown:
            return isChinese ? "先听听身体的声音" : "Listen inward for a moment"
        }
    }

    private func loadEntries() -> [ReflectionEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ReflectionEntry].self, from: data)) ?? []
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func state(for hrvValue: Double?) -> ReflectionState {
        guard let hrvValue else { return .unknown }
        if hrvValue >= 60 { return .restored }
        if hrvValue >= 40 { return .balanced }
        return .low
    }

    private static func question(for state: ReflectionState, on date: Date) -> String {
        let questions: [String]
        if isChinese {
            switch state {
            case .low:
                questions = [
                    "此刻最让你紧绷的一件事是什么？它真的需要现在解决吗？",
                    "如果只允许你先放下一件事，你会选择放下什么？",
                    "你的身体正在提醒你慢一点。现在最需要被照顾的是什么？"
                ]
            case .balanced:
                questions = [
                    "今天有什么小事值得你慢一点对待？",
                    "此刻你的能量更需要推进，还是更需要整理？",
                    "如果把今天的节奏调轻一点，你会先调整哪里？"
                ]
            case .restored:
                questions = [
                    "现在的稳定感来自哪里？你可以如何保留它？",
                    "今天有什么让你觉得自己被支持着？",
                    "如果把这份平静带给接下来的一小时，你会怎么做？"
                ]
            case .unknown:
                questions = [
                    "现在闭眼感受一下：今天你的身体最想告诉你什么？",
                    "如果用一句话描述此刻的自己，那句话会是什么？",
                    "今天你最想温柔地照顾自己的哪一部分？"
                ]
            }
        } else {
            switch state {
            case .low:
                questions = [
                    "What is creating the most tension right now, and does it truly need to be solved this minute?",
                    "If you could set down one thing first, what would it be?",
                    "Your body may be asking you to slow down. What needs care right now?"
                ]
            case .balanced:
                questions = [
                    "What small part of today deserves a slower pace?",
                    "Does your energy need momentum right now, or does it need space to settle?",
                    "If you softened today's rhythm a little, where would you begin?"
                ]
            case .restored:
                questions = [
                    "Where is this steadiness coming from, and how can you keep a little of it?",
                    "What helped you feel supported today?",
                    "How would you carry this calm into the next hour?"
                ]
            case .unknown:
                questions = [
                    "Close your eyes for a moment: what is your body trying to tell you today?",
                    "If you described yourself in one sentence right now, what would it be?",
                    "What part of you most wants gentle care today?"
                ]
            }
        }

        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return questions[day % questions.count]
    }

    private static func dateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func displayDate(for dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateKey) else {
            return dateKey
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private static var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    private var isChinese: Bool {
        Self.isChinese
    }
}
