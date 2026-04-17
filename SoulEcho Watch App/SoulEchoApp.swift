//
//  SoulEchoApp.swift
//  SoulEcho Watch App
//
//  Created by Ziyang Tan on 4/6/26.
//

import SwiftUI
import WatchKit
import UserNotifications

@main
struct SoulEcho_Watch_AppApp: App {
    
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .backgroundTask(.appRefresh("com.ziyang.SoulEcho.healthCheck")) {
            print("[BG] 🔔 Background refresh fired at \(Date())")
            await HealthObserverManager.shared.performHealthCheck(isBackground: true)
            AppDelegate.scheduleNextRefresh()
        }
    }
}

// MARK: - WatchKit App Delegate

class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func applicationDidFinishLaunching() {
        print("[App] ✅ didFinishLaunching")
        
        // 将自己设为通知代理 → 让前台也能显示通知
        UNUserNotificationCenter.current().delegate = self
        
        // 请求权限
        HealthObserverManager.shared.requestAuthorization()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("[Notif] Permission granted: \(granted)")
        }
        
        // 预约后台刷新
        AppDelegate.scheduleNextRefresh()
        
        // 预约一个 30 分钟后的提醒通知（即使后台不 fire，这个通知也会准时到达）
        HealthObserverManager.shared.scheduleDelayedHealthCheck()
    }
    
    func applicationDidBecomeActive() {
        print("[App] 👀 didBecomeActive")
        AppDelegate.scheduleNextRefresh()
        // 重新预约延迟通知
        HealthObserverManager.shared.scheduleDelayedHealthCheck()
    }
    
    // MARK: - 关键：允许前台显示通知
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 即使 App 在前台，也弹出通知 + 声音
        return [.banner, .sound]
    }
    
    // MARK: - 后台刷新预约
    
    static func scheduleNextRefresh() {
        let targetDate = Date().addingTimeInterval(15 * 60)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: targetDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("[BG] ❌ Schedule failed: \(error.localizedDescription)")
            } else {
                print("[BG] ✅ Next refresh at ~\(targetDate)")
            }
        }
    }
}
