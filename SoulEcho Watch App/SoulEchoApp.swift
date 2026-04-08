//
//  SoulEchoApp.swift
//  SoulEcho Watch App
//
//  Created by Ziyang Tan on 4/6/26.
//

import SwiftUI

@main
struct SoulEcho_Watch_AppApp: App {
    init() {
        // 请求后台监控权限和通知权限
        HealthObserverManager.shared.requestAuthorization()
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
