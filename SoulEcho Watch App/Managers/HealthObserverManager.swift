import Foundation
import HealthKit
import UserNotifications

final class HealthObserverManager: @unchecked Sendable {
    static let shared = HealthObserverManager()
    
    private let healthStore = HKHealthStore()
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    // 实时步数监听
    private var stepObserverQuery: HKObserverQuery?
    
    // Keys
    private let sedentaryNotifActiveKey = "sedentaryNotifActive"
    private let stressNotifActiveKey = "stressNotifActive"
    
    // 参数
    private let sedentaryInterval: TimeInterval = 60 * 60  // 久坐：1小时间隔
    private let sedentaryBatchCount = 4                     // 久坐：4条（覆盖4小时）
    private let stressInterval: TimeInterval = 2 * 60 * 60 // 压力：2小时检测（不要太密）
    private let stressBatchCount = 2                        // 压力：2条（覆盖4小时）
    
    // MARK: - 权限
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HK] ❌ HealthKit not available")
            return
        }
        healthStore.requestAuthorization(toShare: nil, read: [hrvType, stepType]) { ok, err in
            print("[HK] Auth result: \(ok), error: \(String(describing: err))")
            if ok {
                self.startStepObserver()
            }
        }
    }
    
    // MARK: - 实时步数监听（用户一走动就取消通知）
    
    func startStepObserver() {
        // 避免重复注册
        if let existing = stepObserverQuery {
            healthStore.stop(existing)
        }
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                print("[HK] 🔴 Step observer error: \(error)")
                completionHandler()
                return
            }
            
            // 有新步数写入 → 检查是否刚活动了
            print("[HK] 👟 Step data updated, checking recent activity...")
            
            Task {
                let recentSteps = await self.getRecentSteps(minutes: 5)
                print("[HK] 👟 Recent steps (5 min): \(recentSteps)")
                
                // 5分钟内超过20步 = 用户在活动
                if recentSteps >= 20 && self.isSedentaryNotifActive() {
                    self.cancelSedentaryNotifications()
                    print("[HK] 🚶 User started moving! Cancelled all pending sedentary notifications")
                }
                completionHandler()
            }
        }
        
        healthStore.execute(query)
        stepObserverQuery = query
        
        // 启用后台投递（让 watchOS 在后台也能收到步数更新）
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if success {
                print("[HK] ✅ Background delivery enabled for steps")
            } else {
                print("[HK] ❌ Background delivery failed: \(String(describing: error))")
            }
        }
    }
    
    // MARK: - 查询最近N分钟步数
    
    private func getRecentSteps(minutes: Int) async -> Double {
        return await withCheckedContinuation { continuation in
            let startTime = Calendar.current.date(byAdding: .minute, value: -minutes, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: startTime, end: Date(), options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: self.stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: steps)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - 智能健康检查（App 被激活时调用）
    //
    // 新逻辑：
    // 1. 检测到久坐 → 启动重复通知（每 N 分钟一次，持续提醒）
    // 2. 检测到用户已活动 → 立即取消重复通知
    // 3. 用户重新坐下 → 等再次检测到久坐时重新启动
    //
    func scheduleDelayedHealthCheck() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        guard hour >= 8 && hour < 24 else {
            print("[Timer] Outside active hours (\(hour)), skipping.")
            cancelSedentaryNotifications()
            cancelStressNotifications()
            return
        }
        
        Task {
            let isSedentary = await checkSedentary()
            let isStressed = await checkStress()
            
            print("[Timer] Check results: sedentary=\(isSedentary), stressed=\(isStressed)")
            
            // --- 久坐逻辑：重复通知 ---
            if isSedentary {
                if !isSedentaryNotifActive() {
                    // 用户刚进入久坐状态，批量预约多条不同内容的提醒
                    await scheduleSedentaryBatch()
                    markSedentaryNotifActive(true)
                    print("[Timer] ✅ Sedentary notification batch scheduled (\(sedentaryBatchCount) notifications)")
                } else {
                    print("[Timer] ℹ️ Repeating sedentary notification already active, no action needed")
                }
            } else {
                // 用户已经活动了！取消重复通知
                if isSedentaryNotifActive() {
                    cancelSedentaryNotifications()
                    print("[Timer] 🚶 User moved! Cancelled sedentary notifications")
                } else {
                    print("[Timer] ℹ️ User is active, no sedentary notifications to cancel")
                }
            }
            
            // --- 压力逻辑：批量通知（每小时一次） ---
            if isStressed {
                if !isStressNotifActive() {
                    await scheduleStressBatch()
                    markStressNotifActive(true)
                    print("[Timer] ✅ Stress notification batch scheduled (\(stressBatchCount) notifications, every 1h)")
                } else {
                    print("[Timer] ℹ️ Stress notifications already active")
                }
            } else {
                if isStressNotifActive() {
                    cancelStressNotifications()
                    print("[Timer] 🧘 HRV recovered! Cancelled stress notifications")
                }
            }
        }
    }
    
    // MARK: - 后台检查（从 backgroundTask 调用）
    
    func performHealthCheck(isBackground: Bool) async {
        print("[HK] Health check (background=\(isBackground)) at \(Date())")
        
        let isSedentary = await checkSedentary()
        let isStressed = await checkStress()
        
        // 久坐：管理重复通知
        if isSedentary {
            if !isSedentaryNotifActive() {
                await scheduleSedentaryBatch()
                markSedentaryNotifActive(true)
                print("[BG] ✅ Sedentary notification batch scheduled")
            }
        } else {
            if isSedentaryNotifActive() {
                cancelSedentaryNotifications()
                print("[BG] 🚶 User moved! Cancelled sedentary notifications")
            }
        }
        
        // 压力：管理批量通知
        if isStressed {
            if !isStressNotifActive() {
                await scheduleStressBatch()
                markStressNotifActive(true)
                print("[BG] ✅ Stress notification batch scheduled")
            }
        } else {
            if isStressNotifActive() {
                cancelStressNotifications()
                print("[BG] 🧘 HRV recovered! Cancelled stress notifications")
            }
        }
    }
    
    // MARK: - 批量久坐通知（每条内容不同）
    
    private func scheduleSedentaryBatch() async {
        // 先取消旧的
        cancelSedentaryNotifications()
        
        let titles = [
            String(localized: "💪 动起来"),
            String(localized: "🚶 该走走了"),
            String(localized: "🌿 活动一下"),
            String(localized: "⏰ 休息时间"),
            String(localized: "🏃 起身动动"),
            String(localized: "✨ 伸展一下"),
            String(localized: "🦵 站起来吧"),
            String(localized: "🌞 出去走走")
        ]
        
        for i in 0..<sedentaryBatchCount {
            let quote = WatchStorage.shared.fetchFastLocalQuote(for: "motivating")
            let delay = sedentaryInterval * Double(i + 1)  // 2min, 4min, 6min...
            
            let content = UNMutableNotificationContent()
            content.title = titles[i % titles.count]
            content.body = quote.content
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "soulecho-sedentary-\(i)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("[Notif] ✅ Batch #\(i) in \(Int(delay/60)) min: \(quote.content.prefix(30))...")
            } catch {
                print("[Notif] ❌ Batch #\(i) failed: \(error)")
            }
        }
    }
    

    
    // MARK: - 取消久坐重复通知
    
    func cancelSedentaryNotifications() {
        let ids = (0..<sedentaryBatchCount).map { "soulecho-sedentary-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        markSedentaryNotifActive(false)
        print("[Notif] 🛑 All \(sedentaryBatchCount) sedentary notifications cancelled")
    }
    
    // MARK: - 批量压力通知（每小时一次，不太密）
    
    private func scheduleStressBatch() async {
        cancelStressNotifications()
        
        let titles = [
            String(localized: "🧘 放松一下"),
            String(localized: "🌿 深呼吸"),
            String(localized: "💭 慢下来"),
            String(localized: "☕ 休息片刻")
        ]
        
        for i in 0..<stressBatchCount {
            let quote = WatchStorage.shared.fetchFastLocalQuote(for: "calming")
            let delay = stressInterval * Double(i + 1)  // 1h, 2h, 3h, 4h
            
            let content = UNMutableNotificationContent()
            content.title = titles[i % titles.count]
            content.body = quote.content
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "soulecho-stress-\(i)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("[Notif] ✅ Stress #\(i) in \(Int(delay/3600))h: \(quote.content.prefix(30))...")
            } catch {
                print("[Notif] ❌ Stress #\(i) failed: \(error)")
            }
        }
    }
    
    // MARK: - 取消压力通知
    
    func cancelStressNotifications() {
        let ids = (0..<stressBatchCount).map { "soulecho-stress-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        markStressNotifActive(false)
        print("[Notif] 🛑 All \(stressBatchCount) stress notifications cancelled")
    }
    
    // MARK: - 久坐检测
    
    private func checkSedentary() async -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 8 && hour < 23 else { return false }
        
        return await withCheckedContinuation { continuation in
            let pastTime = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
            let predicate = HKQuery.predicateForSamples(withStart: pastTime, end: Date(), options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: self.stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                print("[HK] Steps (2h): \(steps) (threshold: <100)")
                continuation.resume(returning: steps < 100)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - 压力检测
    
    private func checkStress() async -> Bool {
        return await withCheckedContinuation { continuation in
            let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: self.hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDesc]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    print("[HK] No HRV data")
                    continuation.resume(returning: false)
                    return
                }
                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                print("[HK] HRV: \(hrv) ms")
                continuation.resume(returning: hrv < 50.0)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - 获取最新 HRV（供 UI 展示）
    
    func fetchLatestHRV() async -> (Double?, Date?) {
        // 先检查授权状态
        let authStatus = healthStore.authorizationStatus(for: hrvType)
        print("[HRV-UI] Authorization status: \(authStatus.rawValue) (0=notDetermined, 1=denied, 2=authorized)")
        
        return await withCheckedContinuation { continuation in
            let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: self.hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDesc]) { _, samples, error in
                if let error = error {
                    print("[HRV-UI] ❌ Query error: \(error)")
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                print("[HRV-UI] Samples count: \(samples?.count ?? 0)")
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    print("[HRV-UI] ⚠️ No HRV samples found")
                    continuation.resume(returning: (nil, nil))
                    return
                }
                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                print("[HRV-UI] ✅ HRV: \(hrv) ms, date: \(sample.endDate)")
                continuation.resume(returning: (hrv, sample.endDate))
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - 状态管理
    
    private func isSedentaryNotifActive() -> Bool {
        return UserDefaults.standard.bool(forKey: sedentaryNotifActiveKey)
    }
    
    private func markSedentaryNotifActive(_ active: Bool) {
        UserDefaults.standard.set(active, forKey: sedentaryNotifActiveKey)
    }
    
    private func isStressNotifActive() -> Bool {
        return UserDefaults.standard.bool(forKey: stressNotifActiveKey)
    }
    
    private func markStressNotifActive(_ active: Bool) {
        UserDefaults.standard.set(active, forKey: stressNotifActiveKey)
    }
}
