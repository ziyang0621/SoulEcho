import Foundation
import HealthKit
import Observation

enum HRVAccessState: Equatable {
    case notDetermined
    case loading
    case available
    case noRecentSample
    case unavailable
    case permissionPossiblyOff
}

@Observable
class HealthService {
    var hrvValue: Double?
    var hrvTimestamp: Date?
    var isLoading = false
    var accessState: HRVAccessState = .notDetermined
    
    private let healthStore = HKHealthStore()
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let permissionRequestedKey = "health_hrv_permission_requested"
    
    func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .unavailable
            return
        }
        
        do {
            accessState = .loading
            isLoading = true
            try await healthStore.requestAuthorization(toShare: [], read: [hrvType])
            UserDefaults.standard.set(true, forKey: permissionRequestedKey)
            await fetchLatestHRV()
        } catch {
            isLoading = false
            accessState = .permissionPossiblyOff
            print("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
    
    func fetchLatestHRV() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .unavailable
            return
        }

        isLoading = true
        accessState = .loading
        defer { isLoading = false }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.accessState = .permissionPossiblyOff
                    print("HRV fetch failed: \(error.localizedDescription)")
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    self.accessState = self.hasRequestedHealthPermission ? .noRecentSample : .notDetermined
                    return
                }

                let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                self.hrvValue = value
                self.hrvTimestamp = sample.endDate
                self.accessState = .available
            }
        }
        
        healthStore.execute(query)
    }

    func refreshAccessState() {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .unavailable
            return
        }

        if hrvValue != nil {
            accessState = .available
        } else if hasRequestedHealthPermission {
            accessState = .noRecentSample
        } else {
            accessState = .notDetermined
        }
    }

    var hasRequestedHealthPermission: Bool {
        UserDefaults.standard.bool(forKey: permissionRequestedKey)
    }

    var shouldShowConnectAction: Bool {
        accessState == .notDetermined
    }

    var shouldShowSettingsAction: Bool {
        accessState == .noRecentSample || accessState == .permissionPossiblyOff
    }

    var hrvUnavailableTitle: String {
        switch accessState {
        case .notDetermined:
            return isChinese ? "连接 Apple 健康" : "Connect Apple Health"
        case .loading:
            return isChinese ? "正在读取 HRV" : "Reading HRV"
        case .available:
            return hrvStatusText
        case .noRecentSample:
            return isChinese ? "暂无近期 HRV" : "No Recent HRV"
        case .unavailable:
            return isChinese ? "此设备不可用" : "Unavailable"
        case .permissionPossiblyOff:
            return isChinese ? "Health 权限可能关闭" : "Health Permission May Be Off"
        }
    }

    var hrvUnavailableMessage: String {
        switch accessState {
        case .notDetermined:
            return isChinese ? "允许 SoulEcho 读取 HRV，用身体信号辅助每日反思。" : "Allow SoulEcho to read HRV so your reflections can include body signals."
        case .loading:
            return isChinese ? "正在从 Apple 健康读取最新心率变异性。" : "Reading your latest heart rate variability from Apple Health."
        case .available:
            return ""
        case .noRecentSample:
            return isChinese ? "可能是 Apple Watch 还没有记录新样本，或 Health 读取权限未开启。" : "Your Apple Watch may not have recorded a recent sample, or Health access may be off."
        case .unavailable:
            return isChinese ? "HealthKit 在当前设备或模拟器上不可用。" : "HealthKit is unavailable on this device or simulator."
        case .permissionPossiblyOff:
            return isChinese ? "请在 Settings 里确认 SoulEcho 可以读取 HRV。" : "Check Settings to confirm SoulEcho can read HRV."
        }
    }

    var connectButtonTitle: String {
        isChinese ? "连接 Apple 健康" : "Connect Apple Health"
    }

    var settingsButtonTitle: String {
        isChinese ? "打开设置" : "Open Settings"
    }

    var refreshButtonTitle: String {
        isChinese ? "刷新" : "Refresh"
    }

    private var isChinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }
    
    var hrvStatusText: String {
        guard let hrv = hrvValue else { return "" }
        if hrv >= 60 {
            return String(localized: "身心放松 ✨")
        } else if hrv >= 40 {
            return String(localized: "状态一般 💛")
        } else {
            return String(localized: "压力偏高 🧘")
        }
    }
    
    var hrvColorName: String {
        guard let hrv = hrvValue else { return "8C7221" } // Fallback to gold
        if hrv >= 60 { return "27AE60" } // Green
        if hrv >= 40 { return "F1C40F" } // Yellow
        return "E74C3C" // Red
    }
    
    var hrvTimeAgoText: String {
        guard let timestamp = hrvTimestamp else { return "" }
        let diff = Int(Date().timeIntervalSince(timestamp) / 60)
        let isEnglish = Locale.current.language.languageCode?.identifier != "zh"
        
        if diff < 1 {
            return isEnglish ? "Updated just now" : "刚刚更新"
        } else if diff < 60 {
            return isEnglish ? "Updated \(diff)m ago" : "\(diff) 分钟前更新"
        } else {
            let hours = diff / 60
            return isEnglish ? "Updated \(hours)h ago" : "\(hours) 小时前更新"
        }
    }
}
