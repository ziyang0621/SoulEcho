import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    func scheduleQuoteNotification(category: String) {
        Task {
            // 1. 获取一条新鲜金句
            let quote = await WatchStorage.shared.fetchFreshQuote(for: category)
            
            // 2. 构造通知内容
            let content = UNMutableNotificationContent()
            content.title = String(localized: "SoulEcho 关怀")
            content.body = quote.content
            content.sound = .default
            
            // 3. 在 1 秒后触发（尽可能近实时的反应后台事件）
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            
            // 4. 交给系统投递
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("Scheduled notification successfully for category: \(category)")
            } catch {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
