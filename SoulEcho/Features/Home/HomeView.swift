import SwiftUI

struct HomeView: View {
    @State private var quoteService = QuoteService()
    @State private var weatherService = WeatherService()
    @State private var healthService = HealthService()
    @State private var reflectionService = ReflectionService()
    @State private var quoteScale: CGFloat = 1.0
    @State private var isShowingReflectionSheet = false
    @State private var isShowingHistory = false
    @State private var isShowingInsights = false
    @FocusState private var isReflectionEditorFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGoldBackground()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isReflectionEditorFocused = false
                    }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 72)
                        
                        // Quote Section
                        if quoteService.isLoading {
                            ProgressView()
                                .tint(Color(hex: "BFA054"))
                        } else if let quote = quoteService.currentQuote {
                            VStack(spacing: 20) {
                                Text("“\(quote.content)”")
                                    .font(.system(size: 28, weight: .semibold, design: .serif))
                                    .foregroundColor(Color(hex: "3B3012"))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                                    .shadow(color: .white.opacity(0.5), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal, 20)
                                
                                Text("- \(quote.author) -")
                                    .font(.system(size: 18, weight: .medium, design: .serif))
                                    .foregroundColor(Color(hex: "5A4C2E"))
                            }
                            .scaleEffect(quoteScale)
                            .onTapGesture {
                                isReflectionEditorFocused = false
                                 withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                     quoteScale = 0.95
                                 }
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                     withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                         quoteScale = 1.0
                                     }
                                 }
                             }
                        }
                        
                        VStack(spacing: 16) {
                            HRVStatusCard(healthService: healthService)
                                .padding(.horizontal, 24)
                                .onTapGesture {
                                    isReflectionEditorFocused = false
                                }
                            
                            ReflectionLauncherCard(
                                reflectionService: reflectionService,
                                openReflection: {
                                    isReflectionEditorFocused = false
                                    isShowingReflectionSheet = true
                                },
                                openHistory: {
                                    isReflectionEditorFocused = false
                                    isShowingHistory = true
                                },
                                openInsights: {
                                    isReflectionEditorFocused = false
                                    isShowingInsights = true
                                }
                            )
                            .padding(.horizontal, 24)
                            
                            // Weather Recommendation Card
                            if let recommendation = weatherService.recommendation {
                                HStack(spacing: 16) {
                                    Image(systemName: recommendation.isSuitableForOutdoor ? "leaf.fill" : "house.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "8C7221"))
                                    
                                    Text(recommendation.message)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "3B3012").opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                                .background(Color.white.opacity(0.3))
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                                .padding(.horizontal, 24)
                                .onTapGesture {
                                    isReflectionEditorFocused = false
                                }
                            } else if weatherService.isLoading {
                                ProgressView()
                                    .tint(Color(hex: "BFA054"))
                            }
                        }
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await quoteService.fetchTodayQuote()
                await weatherService.fetchWeatherRecommendation()
                await healthService.requestAuthorizationAndFetch()
            }
            .onChange(of: healthService.hrvValue) { _, newValue in
                reflectionService.syncTodayHRV(newValue)
                reflectionService.refreshQuestion(hrvValue: newValue)
            }
            .navigationDestination(isPresented: $isShowingHistory) {
                ReflectionHistoryView(entries: reflectionService.entries)
            }
            .navigationDestination(isPresented: $isShowingInsights) {
                ReflectionInsightsView(entries: reflectionService.entries)
            }
            .sheet(isPresented: $isShowingReflectionSheet) {
                DailyReflectionSheet(
                    reflectionService: reflectionService,
                    isAnswerFocused: $isReflectionEditorFocused,
                    hrvValue: healthService.hrvValue,
                    quote: quoteService.currentQuote,
                    openHistory: {
                        isShowingReflectionSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            isShowingHistory = true
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
     }
 }

private struct AnimatedGoldBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "FFFFFF"), Color(hex: "F8F6F0"), Color(hex: "DCCA87")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct HRVStatusCard: View {
    let healthService: HealthService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(Color(hex: healthService.hrvColorName))
                    .font(.title2)

                Text(isChinese ? "HRV数据" : "HRV Data")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.8))

                Spacer()

                Text(hrvValueText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: healthService.hrvColorName))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(statusText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "3B3012"))

                Spacer()

                if healthService.hrvTimestamp != nil {
                    Text(healthService.hrvTimeAgoText)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "5A4C2E").opacity(0.6))
                }
            }

            if healthService.hrvValue == nil {
                Text(isChinese ? "授权 Health 后，Apple Watch 的最新 HRV 会显示在这里。" : "After Health access is granted, your latest Apple Watch HRV will appear here.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.3))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var hrvValueText: String {
        guard let hrv = healthService.hrvValue else { return "-- ms" }
        return "\(Int(hrv)) ms"
    }

    private var statusText: String {
        guard healthService.hrvValue != nil else {
            return isChinese ? "等待最新数据" : "Waiting for latest data"
        }
        return healthService.hrvStatusText
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct ReflectionLauncherCard: View {
    @Bindable var reflectionService: ReflectionService
    let openReflection: () -> Void
    let openHistory: () -> Void
    let openInsights: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: reflectionService.hasSavedToday ? "checkmark.bubble.fill" : "text.bubble.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: reflectionService.hasSavedToday ? "27AE60" : "8C7221"))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isChinese ? "今日反思" : "Daily Reflection")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "3B3012"))

                    Text(reflectionSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "5A4C2E").opacity(0.66))
                }

                Spacer()

                Text("\(reflectionService.checkIn.completedCount)/3")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: reflectionService.checkIn.isComplete ? "27AE60" : "8C7221"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.36))
                    .clipShape(Capsule())
            }

            Text(reflectionService.currentQuestion)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(Color(hex: "3B3012").opacity(0.9))
                .lineLimit(2)
                .lineSpacing(3)

            HStack(spacing: 8) {
                Button(action: openHistory) {
                    Label(isChinese ? "历史" : "History", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color(hex: "8C7221"))

                Button(action: openInsights) {
                    Label(isChinese ? "洞察" : "Insights", systemImage: "chart.xyaxis.line")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color(hex: "8C7221"))

                Spacer(minLength: 0)

                Button(action: openReflection) {
                    Label(reflectionService.hasSavedToday ? (isChinese ? "编辑" : "Edit") : (isChinese ? "开始" : "Start"), systemImage: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "8C7221"))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.3))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var reflectionSubtitle: String {
        if let entry = reflectionService.todayEntry {
            return (isChinese ? "已保存 " : "Saved ") + entry.updatedAt.formatted(date: .omitted, time: .shortened)
        }

        return reflectionService.stateLabel
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct DailyReflectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var reflectionService: ReflectionService
    @FocusState.Binding var isAnswerFocused: Bool
    let hrvValue: Double?
    let quote: Quote?
    let openHistory: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isChinese ? "今日反思" : "Daily Reflection")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "3B3012"))

                        Text(isChinese ? "用 3 个选择题把身体感受和 HRV 对齐。" : "Use three choices to align body signals with HRV.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "5A4C2E").opacity(0.7))
                    }

                    Text(reflectionService.currentQuestion)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(Color(hex: "3B3012"))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    DailyCheckInSection(reflectionService: reflectionService) {
                        isAnswerFocused = false
                    }

                    ZStack(alignment: .topLeading) {
                        if reflectionService.draftAnswer.isEmpty {
                            Text(isChinese ? "写一句就好，给此刻的自己留个回声。" : "One sentence is enough. Leave an echo for this moment.")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "5A4C2E").opacity(0.45))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        }

                        TextEditor(text: $reflectionService.draftAnswer)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "3B3012"))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 112)
                            .focused($isAnswerFocused)
                    }
                    .background(Color.white.opacity(0.36))
                    .cornerRadius(16)

                    HStack(spacing: 10) {
                        Button {
                            isAnswerFocused = false
                            openHistory()
                        } label: {
                            Label(isChinese ? "历史" : "History", systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "8C7221"))

                        Button {
                            guard canSave else { return }

                            if reflectionService.saveTodayAnswer(hrvValue: hrvValue, quote: quote) {
                                isAnswerFocused = false
                                dismiss()
                            }
                        } label: {
                            Label(
                                reflectionService.hasSavedToday ? (isChinese ? "更新" : "Update") : (isChinese ? "保存" : "Save"),
                                systemImage: reflectionService.hasSavedToday ? "checkmark.circle.fill" : "square.and.pencil"
                            )
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "8C7221"))
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)
                    }
                }
                .padding(24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AnimatedGoldBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAnswerFocused = false
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "5A4C2E").opacity(0.55))
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !reflectionService.draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reflectionService.checkIn.hasAnySelection
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct DailyCheckInSection: View {
    @Bindable var reflectionService: ReflectionService
    let dismissKeyboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(isChinese ? "身心签到" : "Mind-Body Check-In", systemImage: "checklist")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.82))

                Spacer()

                Text("\(reflectionService.checkIn.completedCount)/3")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: reflectionService.checkIn.isComplete ? "27AE60" : "8C7221"))
            }

            CheckInQuestionRow(
                title: isChinese ? "身体扫描" : "Physical Scan",
                prompt: isChinese ? "此刻身体感觉如何？" : "How does my body feel right now?",
                options: [
                    CheckInOption(choice: .a, title: isChinese ? "紧绷" : "Braced", detail: isChinese ? "肩颈、呼吸或下颌有点紧" : "Shoulders, breath, or jaw feels tight"),
                    CheckInOption(choice: .b, title: isChinese ? "中性" : "Neutral", detail: isChinese ? "不紧也不特别放松" : "Neither tense nor deeply relaxed"),
                    CheckInOption(choice: .c, title: isChinese ? "沉稳" : "Grounded", detail: isChinese ? "肌肉较松，呼吸更深" : "Loose muscles and easier breathing")
                ],
                selection: $reflectionService.checkIn.physical,
                dismissKeyboard: dismissKeyboard
            )

            CheckInQuestionRow(
                title: isChinese ? "思绪速度" : "Mental Pace",
                prompt: isChinese ? "现在脑内转速如何？" : "What is the current speed of my thoughts?",
                options: [
                    CheckInOption(choice: .a, title: isChinese ? "高转速" : "High RPM", detail: isChinese ? "任务、担忧或待办在跳来跳去" : "Jumping between tasks, worries, or lists"),
                    CheckInOption(choice: .b, title: isChinese ? "中速" : "Moderate", detail: isChinese ? "有想法，但还能选择焦点" : "Thinking, but able to choose focus"),
                    CheckInOption(choice: .c, title: isChinese ? "低转速" : "Low RPM", detail: isChinese ? "慢、安静，或沉浸在当下" : "Slow, quiet, or present")
                ],
                selection: $reflectionService.checkIn.mental,
                dismissKeyboard: dismissKeyboard
            )

            CheckInQuestionRow(
                title: isChinese ? "情绪过滤器" : "Emotional Filter",
                prompt: isChinese ? "今天遇到小波动时，我通常如何反应？" : "How am I reacting to unexpected blips today?",
                options: [
                    CheckInOption(choice: .a, title: isChinese ? "易被触发" : "Reactive", detail: isChinese ? "小事也容易烦躁或压倒我" : "Small interruptions feel frustrating"),
                    CheckInOption(choice: .b, title: isChinese ? "能观察" : "Observant", detail: isChinese ? "有压力，但我还能稳住" : "I notice stressors and stay steady"),
                    CheckInOption(choice: .c, title: isChinese ? "顺流" : "Flowing", detail: isChinese ? "能放过小事，感觉更有余裕" : "Capable, positive, letting little things pass")
                ],
                selection: $reflectionService.checkIn.emotional,
                dismissKeyboard: dismissKeyboard
            )
        }
        .padding(14)
        .background(Color.white.opacity(0.18))
        .cornerRadius(16)
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

private struct CheckInOption: Identifiable {
    let choice: CheckInChoice
    let title: String
    let detail: String

    var id: CheckInChoice { choice }
}

private struct CheckInQuestionRow: View {
    let title: String
    let prompt: String
    let options: [CheckInOption]
    @Binding var selection: CheckInChoice?
    let dismissKeyboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "3B3012"))

                Text(prompt)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "5A4C2E").opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                ForEach(options) { option in
                    CheckInOptionButton(
                        option: option,
                        isSelected: selection == option.choice
                    ) {
                        selection = option.choice
                        dismissKeyboard()
                    }
                }
            }
        }
    }
}

private struct CheckInOptionButton: View {
    let option: CheckInOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(option.choice.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color(hex: "8C7221"))
                    .frame(width: 22, height: 22)
                    .background(isSelected ? Color(hex: "8C7221") : Color.white.opacity(0.50))
                    .clipShape(Circle())

                Text(option.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "3B3012"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(isSelected ? Color(hex: "DCCA87").opacity(0.34) : Color.white.opacity(0.20))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: isSelected ? "8C7221" : "DCCA87").opacity(isSelected ? 0.42 : 0.18), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.choice.rawValue.uppercased()), \(option.title), \(option.detail)")
    }
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    HomeView()
}
