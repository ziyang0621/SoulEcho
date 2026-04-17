import Foundation
import HealthKit
import UserNotifications

final class HealthObserverManager: @unchecked Sendable {
    static let shared = HealthObserverManager()
    
    private let healthStore = HKHealthStore()
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    // 冷却 Keys
    private let lastCalmingKey = "lastCalmingDate"
    private let lastMotivatingKey = "lastMotivatingDate"
    private let cooldown: TimeInterval = 2 * 60 * 60 // 正常：2小时冷却
    
    // MARK: - 权限
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HK] ❌ HealthKit not available")
            return
        }
        healthStore.requestAuthorization(toShare: nil, read: [hrvType, stepType]) { ok, err in
            print("[HK] Auth result: \(ok), error: \(String(describing: err))")
        }
    }
    
    // MARK: - 延迟定时通知（最可靠的方式）
    //
    // 原理：每次用户打开 App 时，我们预约一个 30 分钟后的本地通知。
    // 本地定时通知由系统保证送达，不依赖后台唤醒。
    // 30 分钟后通知到达时，用户一般已经放下手腕了，通知会正常显示。
    //
    func scheduleDelayedHealthCheck() {
        // 先取消之前的定时通知，避免重复
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["soulecho-sedentary-timer", "soulecho-stress-timer"]
        )
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        guard hour >= 8 && hour < 22 else {
            print("[Timer] Outside active hours (\(hour)), skipping.")
            return
        }
        
        // 检查冷却
        let canSendMotivating = canSend(forKey: lastMotivatingKey)
        let canSendCalming = canSend(forKey: lastCalmingKey)
        
        if !canSendMotivating && !canSendCalming {
            print("[Timer] Both on cooldown, skipping.")
            return
        }
        
        // 检查当前健康数据，然后预约延迟通知
        Task {
            let isSedentary = await checkSedentary()
            let isStressed = await checkStress()
            
            print("[Timer] Check results: sedentary=\(isSedentary), stressed=\(isStressed)")
            
            if isStressed && canSendCalming {
                let quote = WatchStorage.shared.fetchFastLocalQuote(for: "calming")
                await scheduleNotification(
                    id: "soulecho-stress-timer",
                    title: "🧘 放松一下",
                    body: quote.content,
                    delay: 30 * 60 // 30分钟后送达
                )
                markSent(forKey: lastCalmingKey)
                print("[Timer] ✅ Calming notification scheduled for 30 min later")
            } else if isSedentary && canSendMotivating {
                let quote = WatchStorage.shared.fetchFastLocalQuote(for: "motivating")
                await scheduleNotification(
                    id: "soulecho-sedentary-timer",
                    title: "💪 动起来",
                    body: quote.content,
                    delay: 30 * 60 // 30分钟后送达
                )
                markSent(forKey: lastMotivatingKey)
                print("[Timer] ✅ Motivating notification scheduled for 30 min later")
            }
        }
    }
    
    // MARK: - 后台检查（从 backgroundTask 调用）
    
    func performHealthCheck(isBackground: Bool) async {
        print("[HK] Health check (background=\(isBackground)) at \(Date())")
        
        let isSedentary = await checkSedentary()
        let isStressed = await checkStress()
        
        if isStressed && canSend(forKey: lastCalmingKey) {
            let quote = WatchStorage.shared.fetchFastLocalQuote(for: "calming")
            await scheduleNotification(
                id: "soulecho-stress-bg",
                title: "🧘 放松一下",
                body: quote.content,
                delay: 5 // 后台模式：5秒后发（App不在前台，可以立刻发）
            )
            markSent(forKey: lastCalmingKey)
        } else if isSedentary && canSend(forKey: lastMotivatingKey) {
            let quote = WatchStorage.shared.fetchFastLocalQuote(for: "motivating")
            await scheduleNotification(
                id: "soulecho-sedentary-bg",
                title: "💪 动起来",
                body: quote.content,
                delay: 5
            )
            markSent(forKey: lastMotivatingKey)
        }
    }
    
    // MARK: - 发送通知
    
    private func scheduleNotification(id: String, title: String, body: String, delay: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[Notif] ✅ Scheduled '\(id)' in \(Int(delay/60)) min")
        } catch {
            print("[Notif] ❌ Failed: \(error)")
        }
    }
    
    // MARK: - 久坐检测
    
    private func checkSedentary() async -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 8 && hour < 22 else { return false }
        
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
    
    // MARK: - 冷却
    
    private func canSend(forKey key: String) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return true }
        return Date().timeIntervalSince(last) >= cooldown
    }
    
    private func markSent(forKey key: String) {
        UserDefaults.standard.set(Date(), forKey: key)
    }
}
