import Foundation
import HealthKit

class HealthObserverManager {
    static let shared = HealthObserverManager()
    
    private let healthStore = HKHealthStore()
    
    // 健康特征类型
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // 我们只需读取
        let typesToRead: Set<HKObjectType> = [hrvType, stepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization successful.")
                self.setupObserverQueries()
            } else {
                print("HealthKit authorization failed: \(String(describing: error))")
            }
        }
    }
    
    private func setupObserverQueries() {
        // HRV - 代表焦虑/压力（高负荷时往往 HRV 偏低）
        let hrvQuery = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] query, completionHandler, error in
            if error != nil { return }
            self?.analyzeHRVAndTrigger()
            completionHandler() // 必须调用完成闭包，证明 App 已经处理完后台唤醒
        }
        
        // 步数 - 代表久坐/缺乏活力
        let stepsQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
            if error != nil { return }
            self?.analyzeStepsAndTrigger()
            completionHandler()
        }
        
        healthStore.execute(hrvQuery)
        healthStore.execute(stepsQuery)
        
        // 注册后台更新（Apple Watch 会在认为合适的时候调用，受电池优化控制）
        // 频率设为 `.hourly` 意思是：尽量一小时汇报一次（如果有新数据的话）
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .hourly) { success, error in
            print("Background delivery for HRV setup: \(success)")
        }
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { success, error in
            print("Background delivery for Steps setup: \(success)")
        }
    }
    
    // MARK: - 逻辑研判
    
    private func analyzeHRVAndTrigger() {
        // 我们拉取最新一条 HRV 数据
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let hrvValue = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            print("Detected new HRV: \(hrvValue) ms")
            
            // 【粗略判断策略】
            // 成年人平均 HRV 大约在 20ms - 80ms。
            // 当突发性焦虑，交感神经紧张时，HRV 往往会锐减（比如下降到 20ms 以下，因人而异）。
            // 这里我们设定一个示例阈值 25ms。如果是低变异率，则推测近期可能处于持续紧张或高压状态。
            if hrvValue < 25.0 {
                // 防骚扰拦截（比如限制一下，只在一天发一条）
                // 暂时这里直接调用
                NotificationManager.shared.scheduleQuoteNotification(category: "calming")
            }
        }
        healthStore.execute(query)
    }
    
    private func analyzeStepsAndTrigger() {
        // 我们拉取过去2小时的步数积累
        let calendar = Calendar.current
        let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: twoHoursAgo, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            print("Detected steps in last 2 hrs: \(steps)")
            
            // 【粗略判断策略】
            // 如果 2 个小时内的总步数少于 50 步，高度疑似处于久坐或者沉睡状态
            // 我们可以在白天唤醒用户，或者发送鼓励。为防止骚扰，同样应当配备防重复机制。
            if steps < 50.0 {
                NotificationManager.shared.scheduleQuoteNotification(category: "motivating")
            }
        }
        healthStore.execute(query)
    }
}
