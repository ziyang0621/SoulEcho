//
//  ContentView.swift
//  SoulEcho Watch App
//
//  Created by Ziyang Tan on 4/6/26.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var quote = ""
    @State private var author = ""
    @State private var isLoading = true
    @State private var hrvValue: Double?
    @State private var hrvTimestamp: Date?
    @State private var hrvAccessState: WatchHRVAccessState = .notDetermined
    
    @State private var hasCheckedInToday = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("今日箴言")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Text("\"\(quote)\"")
                            .font(.system(.body, design: .serif))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            
                        Text("- \(author) -")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 7) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundStyle(hrvColor)
                                .font(.title3)
                            Text("HRV")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let hrv = hrvValue {
                                Text("\(Int(hrv)) ms")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(hrvColor)
                            } else {
                                Text("--")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let hrv = hrvValue {
                            HStack {
                                Text(hrvStatusText(hrv))
                                    .font(.caption2)
                                    .foregroundStyle(hrvColor.opacity(0.8))
                                Spacer()
                                if let time = hrvTimestamp {
                                    Text(time, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            HStack {
                                Text(hrvUnavailableTitle)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(hrvColor)
                                Spacer()
                            }

                            Text(hrvUnavailableMessage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 2)
                    
                    NavigationLink(destination: QuickCheckInView()) {
                        HStack {
                            Image(systemName: hasCheckedInToday ? "checkmark.circle.fill" : "face.smiling.inverse")
                            Text(hasCheckedInToday
                                 ? (isChinese ? "已打卡 ✓" : "Checked in ✓")
                                 : (isChinese ? "快速打卡" : "Quick Check-in"))
                        }
                    }
                    .tint(hasCheckedInToday ? .gray : .orange)
                    .padding(.top, 10)
                    
                    NavigationLink(destination: ReflectView()) {
                        HStack {
                            Image(systemName: "lungs.fill")
                            Text("开始静心 60s")
                        }
                    }
                    .tint(.cyan)
                    .padding(.top, 2)
                }
            }
        }
        .task {
            let result = await WatchStorage.shared.fetchFreshQuote()
            quote = result.content
            author = result.author
            isLoading = false
            
            // Fetch HRV
            let snapshot = await HealthObserverManager.shared.fetchLatestHRV()
            hrvValue = snapshot.value
            hrvTimestamp = snapshot.timestamp
            hrvAccessState = snapshot.accessState
            
            // Check if already checked in today
            hasCheckedInToday = WatchStorage.shared.hasCheckedInToday()
        }
        .onAppear {
            hasCheckedInToday = WatchStorage.shared.hasCheckedInToday()
        }
    }
    
    private var hrvColor: Color {
        guard let hrv = hrvValue else { return .gray }
        if hrv >= 60 { return .green }
        if hrv >= 40 { return .yellow }
        return .red
    }
    
    private func hrvStatusText(_ hrv: Double) -> String {
        if hrv >= 60 {
            return String(localized: "身心放松 ✨")
        } else if hrv >= 40 {
            return String(localized: "状态一般 💛")
        } else {
            return String(localized: "压力偏高 🧘")
        }
    }

    private var hrvUnavailableTitle: String {
        switch hrvAccessState {
        case .notDetermined:
            return String(localized: "Allow Health")
        case .available:
            return ""
        case .noRecentSample:
            return String(localized: "No recent sample")
        case .unavailable:
            return String(localized: "Unavailable")
        case .permissionPossiblyOff:
            return String(localized: "Check iPhone")
        }
    }

    private var hrvUnavailableMessage: String {
        switch hrvAccessState {
        case .notDetermined:
            return String(localized: "Open iPhone to connect.")
        case .available:
            return ""
        case .noRecentSample:
            return String(localized: "Wear Apple Watch longer.")
        case .unavailable:
            return String(localized: "Health is not available.")
        case .permissionPossiblyOff:
            return String(localized: "Review Health settings.")
        }
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
}

#Preview {
    ContentView()
}
