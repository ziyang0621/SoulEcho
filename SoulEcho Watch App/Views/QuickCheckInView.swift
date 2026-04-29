import SwiftUI

struct QuickCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScore: Int?
    @State private var showConfirmation = false
    @State private var hasCheckedIn: Bool

    private let isChinese = Locale.current.language.languageCode?.identifier == "zh"

    init() {
        _hasCheckedIn = State(initialValue: WatchStorage.shared.hasCheckedInToday())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if showConfirmation || hasCheckedIn {
                    confirmedView
                } else {
                    checkInView
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle(isChinese ? "快速打卡" : "Check-in")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Check-in Selection

    private var checkInView: some View {
        VStack(spacing: 16) {
            Text(isChinese ? "今天感觉怎么样？" : "How do you feel?")
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                moodButton(emoji: "😌", label: isChinese ? "放松" : "Relaxed", score: 1, color: .green)
                moodButton(emoji: "😐", label: isChinese ? "一般" : "Neutral", score: 2, color: .yellow)
                moodButton(emoji: "😰", label: isChinese ? "紧绷" : "Tense", score: 3, color: .red)
            }
        }
    }

    private func moodButton(emoji: String, label: String, score: Int, color: Color) -> some View {
        Button {
            selectedScore = score
            WatchStorage.shared.saveQuickCheckIn(score: score)
            HapticsManager.shared.playSuccess()

            withAnimation(.easeInOut(duration: 0.3)) {
                showConfirmation = true
            }

            // Auto-dismiss after 1.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
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

            if let score = selectedScore ?? WatchStorage.shared.loadTodayQuickCheckIn() {
                Text(emojiFor(score: score))
                    .font(.system(size: 28))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func emojiFor(score: Int) -> String {
        switch score {
        case 1: return "😌"
        case 2: return "😐"
        case 3: return "😰"
        default: return "😐"
        }
    }
}

#Preview {
    QuickCheckInView()
}
