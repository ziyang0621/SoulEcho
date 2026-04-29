import SwiftUI

struct QuickCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var physical: Int?
    @State private var mental: Int?
    @State private var emotional: Int?
    @State private var currentStep = 0
    @State private var showConfirmation = false
    @State private var hasCheckedIn: Bool

    private let isChinese = Locale.current.language.languageCode?.identifier == "zh"

    private var steps: [(title: String, emoji: [(String, String, Int)])] {
        [
            (
                title: isChinese ? "身体感觉" : "Physical Scan",
                emoji: [
                    ("😌", isChinese ? "轻松" : "Light", 1),
                    ("😐", isChinese ? "一般" : "Neutral", 2),
                    ("😩", isChinese ? "沉重" : "Heavy", 3)
                ]
            ),
            (
                title: isChinese ? "思维节奏" : "Mental Pace",
                emoji: [
                    ("🧘", isChinese ? "平静" : "Calm", 1),
                    ("😐", isChinese ? "一般" : "Neutral", 2),
                    ("🌀", isChinese ? "纷乱" : "Racing", 3)
                ]
            ),
            (
                title: isChinese ? "情绪状态" : "Emotional Filter",
                emoji: [
                    ("😊", isChinese ? "正面" : "Positive", 1),
                    ("😐", isChinese ? "平淡" : "Flat", 2),
                    ("😰", isChinese ? "紧绷" : "Tense", 3)
                ]
            )
        ]
    }

    init() {
        _hasCheckedIn = State(initialValue: WatchStorage.shared.hasCheckedInToday())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showConfirmation || hasCheckedIn {
                    confirmedView
                } else {
                    stepView
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle(isChinese ? "快速打卡" : "Check-in")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step View

    private var stepView: some View {
        let step = steps[currentStep]
        return VStack(spacing: 14) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i == currentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            Text(step.title)
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(step.emoji, id: \.2) { emoji, label, score in
                    moodButton(emoji: emoji, label: label, score: score)
                }
            }
        }
    }

    private func moodButton(emoji: String, label: String, score: Int) -> some View {
        let color: Color = score == 1 ? .green : (score == 2 ? .yellow : .red)
        return Button {
            selectScore(score)
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 28))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    private func selectScore(_ score: Int) {
        HapticsManager.shared.playBreatheIn()

        switch currentStep {
        case 0: physical = score
        case 1: mental = score
        case 2: emotional = score
        default: break
        }

        if currentStep < 2 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep += 1
            }
        } else {
            // All 3 done — save and show confirmation
            WatchStorage.shared.saveQuickCheckIn(
                physical: physical ?? 2,
                mental: mental ?? 2,
                emotional: score
            )
            HapticsManager.shared.playSuccess()

            withAnimation(.easeInOut(duration: 0.3)) {
                showConfirmation = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    // MARK: - Confirmation

    private var confirmedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))

            Text(isChinese ? "已记录" : "Recorded")
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 16) {
                summaryDot(emoji: emojiFor(step: 0, score: physical), label: isChinese ? "身体" : "Body")
                summaryDot(emoji: emojiFor(step: 1, score: mental), label: isChinese ? "思维" : "Mind")
                summaryDot(emoji: emojiFor(step: 2, score: emotional), label: isChinese ? "情绪" : "Mood")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func summaryDot(emoji: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.title3)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private func emojiFor(step: Int, score: Int?) -> String {
        guard let s = score else { return "—" }
        let options = steps[step].emoji
        return options.first { $0.2 == s }?.0 ?? "😐"
    }
}

#Preview {
    QuickCheckInView()
}
