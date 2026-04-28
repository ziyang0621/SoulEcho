import SwiftUI

struct ReflectionHistoryView: View {
    let entries: [ReflectionEntry]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFFFFF"), Color(hex: "F8F6F0"), Color(hex: "DCCA87")],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if entries.isEmpty {
                ContentUnavailableView(
                    isChinese ? "还没有回声" : "No Echoes Yet",
                    systemImage: "text.bubble",
                    description: Text(isChinese ? "保存一次今日反思后，它会出现在这里。" : "Saved daily reflections will appear here.")
                )
                .foregroundStyle(Color(hex: "3B3012"))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(entries) { entry in
                            ReflectionHistoryRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(isChinese ? "回声记录" : "Echo Journal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct ReflectionHistoryRow: View {
    let entry: ReflectionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(ReflectionService.displayDate(for: entry.dateKey))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.72))

                Spacer()

                Label(hrvText, systemImage: "heart.text.square.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: entry.hrvValue == nil ? "5A4C2E" : "8C7221").opacity(entry.hrvValue == nil ? 0.45 : 0.85))
            }

            Text(entry.question)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(Color(hex: "3B3012"))
                .lineSpacing(4)

            if let checkIn = entry.checkIn, checkIn.hasAnySelection {
                HistoryCheckInSummary(checkIn: checkIn)
            }

            if !entry.answer.isEmpty {
                Text(entry.answer)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "3B3012").opacity(0.86))
                    .lineSpacing(4)
            }

            if let quoteContent = entry.quoteContent {
                Divider()
                    .background(Color(hex: "8C7221").opacity(0.2))

                Text("“\(quoteContent)”")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.72))
                    .lineSpacing(3)

                if let quoteAuthor = entry.quoteAuthor {
                    Text("- \(quoteAuthor) -")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(Color(hex: "5A4C2E").opacity(0.55))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.32))
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var hrvText: String {
        guard let hrvValue = entry.hrvValue else {
            return isChinese ? "无 HRV" : "No HRV"
        }

        return "\(Int(hrvValue)) ms"
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct HistoryCheckInSummary: View {
    let checkIn: DailyCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isChinese ? "身心签到" : "Mind-Body Check-In")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.72))

                Spacer()

                if let averageScore = checkIn.averageScore {
                    Text(String(format: "%.1f / 3", averageScore))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "8C7221"))
                }
            }

            VStack(spacing: 6) {
                HistoryCheckInLine(title: isChinese ? "身体" : "Body", choice: checkIn.physical, labels: physicalLabels)
                HistoryCheckInLine(title: isChinese ? "思绪" : "Mind", choice: checkIn.mental, labels: mentalLabels)
                HistoryCheckInLine(title: isChinese ? "情绪" : "Emotion", choice: checkIn.emotional, labels: emotionalLabels)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.20))
        .cornerRadius(14)
    }

    private var physicalLabels: [CheckInChoice: String] {
        [
            .a: isChinese ? "紧绷" : "Braced",
            .b: isChinese ? "中性" : "Neutral",
            .c: isChinese ? "沉稳" : "Grounded"
        ]
    }

    private var mentalLabels: [CheckInChoice: String] {
        [
            .a: isChinese ? "高转速" : "High RPM",
            .b: isChinese ? "中速" : "Moderate",
            .c: isChinese ? "低转速" : "Low RPM"
        ]
    }

    private var emotionalLabels: [CheckInChoice: String] {
        [
            .a: isChinese ? "易被触发" : "Reactive",
            .b: isChinese ? "能观察" : "Observant",
            .c: isChinese ? "顺流" : "Flowing"
        ]
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct HistoryCheckInLine: View {
    let title: String
    let choice: CheckInChoice?
    let labels: [CheckInChoice: String]

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "5A4C2E").opacity(0.62))
                .frame(width: 54, alignment: .leading)

            if let choice {
                Text(choice.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color(hex: "8C7221"))
                    .clipShape(Circle())

                Text(labels[choice] ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "3B3012").opacity(0.82))
            } else {
                Text(Locale.current.language.languageCode?.identifier == "zh" ? "未选择" : "Not selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.45))
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        ReflectionHistoryView(entries: [
            ReflectionEntry(
                id: UUID(),
                dateKey: "2026-04-26",
                question: "What part of you most wants gentle care today?",
                answer: "I need to stop rushing and take the evening slowly.",
                checkIn: DailyCheckIn(physical: .b, mental: .a, emotional: .b),
                hrvValue: 48,
                quoteContent: "Every breath is an opportunity to let a tense soul become light again.",
                quoteAuthor: "SoulEcho",
                createdAt: Date(),
                updatedAt: Date()
            )
        ])
    }
}
