import SwiftUI

struct ReflectionInsightsView: View {
    let entries: [ReflectionEntry]

    private var stats: ReflectionInsightStats {
        ReflectionInsightStats(entries: entries)
    }

    var body: some View {
        ZStack {
            InsightGoldBackground()

            if stats.loggedDays.isEmpty {
                ContentUnavailableView(
                    isChinese ? "还没有足够数据" : "Not Enough Data Yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text(isChinese ? "完成几天的身心签到后，这里会显示 HRV 与主观感受的 60 天洞察。" : "After a few daily check-ins, this dashboard will show 60-day HRV and feeling insights.")
                )
                .foregroundStyle(Color(hex: "3B3012"))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        metricGrid
                        TrendOverlapCard(stats: stats)
                        QuadrantMapCard(stats: stats)
                        HeatmapCard(stats: stats)
                        InsightActionList(stats: stats)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(isChinese ? "60 天洞察" : "60-Day Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isChinese ? "60 天身心分析" : "60-Day Mind-Body Analysis")
                .font(.system(size: 31, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "3B3012"))

            Text(isChinese ? "把 HRV 和每日选择题放在一起看，找出你的压力信号和恢复模式。" : "Correlate HRV with daily check-ins to find your stress signature and recovery patterns.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "5A4C2E").opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var metricGrid: some View {
        VStack(spacing: 12) {
            InsightMetricCard(
                icon: "waveform.path.ecg",
                title: isChinese ? "平均 HRV" : "Avg. HRV",
                value: stats.averageHRV.map { "\(Int($0.rounded())) ms" } ?? "--",
                tint: Color(hex: "3366CC")
            )

            InsightMetricCard(
                icon: "brain.head.profile",
                title: isChinese ? "主观韧性" : "Resilience",
                value: stats.averageSubjective.map { String(format: "%.1f / 3", $0) } ?? "--",
                tint: Color(hex: "16A085")
            )

            InsightMetricCard(
                icon: "arrow.up.right",
                title: isChinese ? "数据对齐度" : "Data Alignment",
                value: stats.alignmentPercent.map { "\($0)%" } ?? "--",
                tint: Color(hex: "9B51E0"),
                subtitle: stats.alignmentSampleText(isChinese: isChinese)
            )
        }
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct ReflectionInsightStats {
    let days: [InsightDay]

    init(entries: [ReflectionEntry]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entryByDate = Dictionary(uniqueKeysWithValues: entries.map { ($0.dateKey, $0) })

        days = (0..<60).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 59, to: today) else { return nil }
            let dateKey = Self.dateKey(for: date)
            return InsightDay(index: offset, date: date, dateKey: dateKey, entry: entryByDate[dateKey])
        }
    }

    var loggedDays: [InsightDay] {
        days.filter { $0.entry != nil }
    }

    var pairedDays: [InsightDay] {
        days.filter { $0.hrvValue != nil && $0.subjectiveScore != nil }
    }

    var averageHRV: Double? {
        average(days.compactMap(\.hrvValue))
    }

    var averageSubjective: Double? {
        average(days.compactMap(\.subjectiveScore))
    }

    var alignmentPercent: Int? {
        let values = pairedDays.compactMap { day -> Double? in
            guard let hrv = day.hrvValue, let subjective = day.subjectiveScore else { return nil }
            let hrvScore = Self.hrvAsSubjectiveScore(hrv)
            return max(0, 1 - abs(hrvScore - subjective) / 2)
        }

        guard let value = average(values) else { return nil }
        return Int((value * 100).rounded())
    }

    var hrvRange: ClosedRange<Double> {
        let values = days.compactMap(\.hrvValue)
        guard let minValue = values.min(), let maxValue = values.max(), minValue != maxValue else {
            return 30...80
        }

        return (minValue - 4)...(maxValue + 4)
    }

    var hrvPivot: Double {
        averageHRV ?? 50
    }

    var falseStressDays: [InsightDay] {
        pairedDays.filter { ($0.hrvValue ?? 0) < hrvPivot && ($0.subjectiveScore ?? 0) >= 2.5 }
    }

    var hiddenTollDays: [InsightDay] {
        pairedDays.filter { ($0.hrvValue ?? 0) >= hrvPivot && ($0.subjectiveScore ?? 3) <= 1.6 }
    }

    var rpmWarningRuns: Int {
        var runs = 0
        var currentRun = 0

        for day in days {
            if day.entry?.checkIn?.mental == .a {
                currentRun += 1
                if currentRun == 2 {
                    runs += 1
                }
            } else {
                currentRun = 0
            }
        }

        return runs
    }

    func alignmentSampleText(isChinese: Bool) -> String {
        let count = pairedDays.count
        if count == 0 {
            return isChinese ? "需要 HRV + 签到样本" : "Needs HRV + check-in samples"
        }

        return isChinese ? "\(count) 天可对比" : "\(count) comparable days"
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func hrvAsSubjectiveScore(_ hrv: Double) -> Double {
        min(max(((hrv - 30) / 40) * 2 + 1, 1), 3)
    }

    private static func dateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct InsightDay: Identifiable {
    let index: Int
    let date: Date
    let dateKey: String
    let entry: ReflectionEntry?

    var id: String { dateKey }
    var hrvValue: Double? { entry?.hrvValue }
    var subjectiveScore: Double? { entry?.checkIn?.averageScore }
}

private struct InsightMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    var subtitle: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 50, height: 50)
                .background(tint.opacity(0.12))
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.72))

                Text(value)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1F2937"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "5A4C2E").opacity(0.58))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.36))
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

private struct TrendOverlapCard: View {
    let stats: ReflectionInsightStats

    var body: some View {
        InsightSectionCard(
            icon: "heart",
            title: isChinese ? "HRV 与主观趋势" : "HRV & Subjective Trend",
            trailing: AnyView(legend)
        ) {
            TrendOverlapChart(stats: stats)
                .frame(height: 190)
                .padding(.top, 8)
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            InsightLegendDot(color: Color(hex: "3366CC"), text: "HRV")
            InsightLegendDot(color: Color(hex: "16A085"), text: isChinese ? "感受" : "Feeling")
        }
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct TrendOverlapChart: View {
    let stats: ReflectionInsightStats

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let hrvPoints = stats.days.compactMap { point(for: $0, size: size, metric: .hrv) }
            let feelingPoints = stats.days.compactMap { point(for: $0, size: size, metric: .feeling) }

            ZStack {
                chartGrid(size: size)

                ForEach(stats.days) { day in
                    if let score = day.subjectiveScore {
                        let x = xPosition(for: day.index, width: size.width)
                        let normalized = (score - 1) / 2
                        let barHeight = max(6, normalized * (size.height - 24))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "16A085").opacity(0.22 + normalized * 0.34))
                            .frame(width: max(3, size.width / 92), height: barHeight)
                            .position(x: x, y: size.height - 12 - barHeight / 2)
                    }
                }

                linePath(points: hrvPoints)
                    .stroke(Color(hex: "3366CC"), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                linePath(points: feelingPoints)
                    .stroke(Color(hex: "16A085"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                ForEach(Array(hrvPoints.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color(hex: "3366CC"), lineWidth: 2))
                        .position(point)
                }
            }
        }
        .accessibilityLabel(isChinese ? "HRV 和主观感受趋势图" : "HRV and subjective trend chart")
    }

    private enum Metric {
        case hrv
        case feeling
    }

    private func point(for day: InsightDay, size: CGSize, metric: Metric) -> CGPoint? {
        let x = xPosition(for: day.index, width: size.width)
        let normalized: Double?

        switch metric {
        case .hrv:
            if let hrv = day.hrvValue {
                let range = stats.hrvRange
                normalized = (hrv - range.lowerBound) / (range.upperBound - range.lowerBound)
            } else {
                normalized = nil
            }
        case .feeling:
            if let score = day.subjectiveScore {
                normalized = (score - 1) / 2
            } else {
                normalized = nil
            }
        }

        guard let normalized else { return nil }
        let clamped = min(max(normalized, 0), 1)
        return CGPoint(x: x, y: size.height - 12 - clamped * (size.height - 24))
    }

    private func xPosition(for index: Int, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return 10 + CGFloat(index) / 59 * (width - 20)
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)

            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func chartGrid(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Color(hex: "8C7221").opacity(0.10))
                    .frame(height: 1)
                    .position(x: size.width / 2, y: 12 + CGFloat(index) / 3 * (size.height - 24))
            }
        }
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct QuadrantMapCard: View {
    let stats: ReflectionInsightStats

    var body: some View {
        InsightSectionCard(
            icon: "square.grid.2x2",
            title: isChinese ? "身心象限图" : "Mind-Body Quadrant Map"
        ) {
            QuadrantMap(stats: stats)
                .frame(height: 230)
                .padding(.top, 8)
        }
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct QuadrantMap: View {
    let stats: ReflectionInsightStats

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Rectangle()
                    .fill(Color(hex: "8C7221").opacity(0.10))
                    .frame(width: 1)
                    .position(x: size.width / 2, y: size.height / 2)

                Rectangle()
                    .fill(Color(hex: "8C7221").opacity(0.10))
                    .frame(height: 1)
                    .position(x: size.width / 2, y: size.height / 2)

                quadrantLabel(isChinese ? "稳定恢复" : "Restored", alignment: .topTrailing)
                    .position(x: size.width * 0.75, y: 18)
                quadrantLabel(isChinese ? "隐藏消耗" : "Hidden toll", alignment: .topLeading)
                    .position(x: size.width * 0.25, y: 18)
                quadrantLabel(isChinese ? "身体疲惫" : "False stress", alignment: .bottomTrailing)
                    .position(x: size.width * 0.75, y: size.height - 18)
                quadrantLabel(isChinese ? "需要恢复" : "Recovery", alignment: .bottomLeading)
                    .position(x: size.width * 0.25, y: size.height - 18)

                ForEach(stats.pairedDays) { day in
                    if let hrv = day.hrvValue, let score = day.subjectiveScore {
                        let x = normalized(hrv, in: stats.hrvRange)
                        let y = (score - 1) / 2

                        Circle()
                            .fill(dotColor(hrv: hrv, score: score))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                            .position(
                                x: 18 + x * (size.width - 36),
                                y: size.height - 18 - y * (size.height - 36)
                            )
                    }
                }
            }
        }
        .accessibilityLabel(isChinese ? "HRV 与主观感受象限图" : "HRV and feeling quadrant map")
    }

    private func normalized(_ value: Double, in range: ClosedRange<Double>) -> CGFloat {
        CGFloat(min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1))
    }

    private func dotColor(hrv: Double, score: Double) -> Color {
        if hrv < stats.hrvPivot && score >= 2.5 { return Color(hex: "16A085") }
        if hrv >= stats.hrvPivot && score <= 1.6 { return Color(hex: "E67E22") }
        if hrv < stats.hrvPivot && score <= 1.6 { return Color(hex: "E74C3C") }
        return Color(hex: "3366CC")
    }

    private func quadrantLabel(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color(hex: "5A4C2E").opacity(0.58))
            .frame(width: 104, alignment: alignment)
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct HeatmapCard: View {
    let stats: ReflectionInsightStats

    var body: some View {
        InsightSectionCard(
            icon: "calendar",
            title: isChinese ? "60 天签到热力图" : "60-Day Check-In Heatmap"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(monthGroups) { group in
                    MonthHeatmapSection(
                        month: group.month,
                        days: group.days,
                        colorForDay: color(for:),
                        accessibilityLabelForDay: accessibilityLabel(for:)
                    )
                }
            }
            .padding(.top, 8)
        }
    }

    private var monthGroups: [HeatmapMonthGroup] {
        let grouped = Dictionary(grouping: stats.days) { monthStart(for: $0.date) }

        return grouped.keys.sorted().map { month in
            HeatmapMonthGroup(
                month: month,
                days: (grouped[month] ?? []).sorted { $0.date < $1.date }
            )
        }
    }

    private func color(for day: InsightDay) -> Color {
        guard let score = day.subjectiveScore else {
            return Color.white.opacity(day.entry == nil ? 0.22 : 0.34)
        }

        if score >= 2.5 { return Color(hex: "16A085").opacity(0.68) }
        if score >= 1.8 { return Color(hex: "DCCA87").opacity(0.74) }
        return Color(hex: "E74C3C").opacity(0.55)
    }

    private func accessibilityLabel(for day: InsightDay) -> String {
        let date = day.date.formatted(date: .abbreviated, time: .omitted)
        guard let score = day.subjectiveScore else {
            return isChinese ? "\(date)，无签到" : "\(date), no check-in"
        }

        return isChinese ? "\(date)，主观分数 \(String(format: "%.1f", score))" : "\(date), subjective score \(String(format: "%.1f", score))"
    }

    private func monthStart(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct HeatmapMonthGroup: Identifiable {
    let month: Date
    let days: [InsightDay]

    var id: Date { month }
}

private struct MonthHeatmapSection: View {
    let month: Date
    let days: [InsightDay]
    let colorForDay: (InsightDay) -> Color
    let accessibilityLabelForDay: (InsightDay) -> String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "5A4C2E").opacity(0.76))

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "5A4C2E").opacity(0.42))
                        .frame(height: 12)
                }

                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: 24)
                }

                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(colorForDay(day))
                        .frame(height: 24)
                        .overlay(
                            Text(dayNumber(for: day.date))
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "3B3012").opacity(day.entry == nil ? 0.28 : 0.72))
                        )
                        .accessibilityLabel(accessibilityLabelForDay(day))
                }
            }
        }
    }

    private var monthTitle: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = DateFormatter().veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let firstIndex = Calendar.current.firstWeekday - 1
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    private var leadingBlankCount: Int {
        guard let firstDate = days.first?.date else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: firstDate)
        let firstWeekday = Calendar.current.firstWeekday
        return (weekday - firstWeekday + 7) % 7
    }

    private func dayNumber(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }
}

private struct InsightActionList: View {
    let stats: ReflectionInsightStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isChinese ? "下一步建议" : "Go-Forward Signals")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "3B3012"))

            ForEach(actions) { action in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(action.tint)
                        .frame(width: 34, height: 34)
                        .background(action.tint.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: "3B3012"))

                        Text(action.detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "5A4C2E").opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color.white.opacity(0.34))
                .background(.ultraThinMaterial)
                .cornerRadius(18)
            }
        }
    }

    private var actions: [InsightAction] {
        [
            InsightAction(
                icon: "drop.fill",
                tint: Color(hex: "16A085"),
                title: isChinese ? "False Stress 指标" : "False Stress Indicator",
                detail: isChinese
                    ? "最近 60 天有 \(stats.falseStressDays.count) 天 HRV 偏低但主观状态不错。遇到这种模式时，优先考虑睡眠、补水或降低训练量。"
                    : "\(stats.falseStressDays.count) recent days show low HRV with steady feelings. When this appears, try sleep, hydration, or lighter training before assuming mental stress."
            ),
            InsightAction(
                icon: "arrow.triangle.2.circlepath",
                tint: Color(hex: "E67E22"),
                title: isChinese ? "Hidden Toll 指标" : "Hidden Toll Indicator",
                detail: isChinese
                    ? "有 \(stats.hiddenTollDays.count) 天 HRV 不低但主观紧绷。它更像脑内噪音，适合做 5 分钟 brain dump 或安静散步。"
                    : "\(stats.hiddenTollDays.count) days show okay HRV but tense feelings. Treat that as mental noise: a 5-minute brain dump or quiet walk may help."
            ),
            InsightAction(
                icon: "speedometer",
                tint: Color(hex: "9B51E0"),
                title: isChinese ? "RPM Warning" : "RPM Warning",
                detail: isChinese
                    ? "连续两天“高转速”出现了 \(stats.rpmWarningRuns) 次。下次连续两天选 A 时，晚上安排一个 Quiet Hour。"
                    : "Two-day High RPM runs appeared \(stats.rpmWarningRuns) times. When A appears two days in a row, schedule a Quiet Hour that evening."
            )
        ]
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct InsightAction: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let detail: String
}

private struct InsightSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let trailing: AnyView?
    let content: Content

    init(
        icon: String,
        title: String,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label(title, systemImage: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "3B3012"))

                Spacer()

                if let trailing {
                    trailing
                }
            }

            content
        }
        .padding(18)
        .background(Color.white.opacity(0.34))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

private struct InsightLegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "3B3012").opacity(0.74))
        }
    }
}

private struct InsightGoldBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "FFFFFF"), Color(hex: "F8F6F0"), Color(hex: "DCCA87")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        ReflectionInsightsView(entries: ReflectionInsightPreview.entries)
    }
}

private enum ReflectionInsightPreview {
    static var entries: [ReflectionEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<36).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let hrv = 42 + Double((offset * 7) % 28)
            let physical: CheckInChoice = offset % 5 == 0 ? .a : (offset % 3 == 0 ? .b : .c)
            let mental: CheckInChoice = offset % 6 < 2 ? .a : (offset % 4 == 0 ? .b : .c)
            let emotional: CheckInChoice = offset % 7 == 0 ? .a : .b

            return ReflectionEntry(
                id: UUID(),
                dateKey: dateKey(for: date),
                question: "What is your body trying to tell you today?",
                answer: "A short note about today's pace.",
                checkIn: DailyCheckIn(physical: physical, mental: mental, emotional: emotional),
                hrvValue: hrv,
                quoteContent: nil,
                quoteAuthor: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }

    private static func dateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
