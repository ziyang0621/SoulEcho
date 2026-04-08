# SoulEcho 🌿

SoulEcho 是一款专注于身心灵滋养和情绪记录的静心应用。通过极高美感的动态视觉、原生 Apple 硬件触感反馈、以及 **AI 驱动的健康情境感知**，为您带来随身的宁静与治愈体验。

目前项目包含 **iOS** 及 **watchOS** 两大组成部分，通过云端数据同步、HealthKit 后台监听与原生 Apple `App Group` 构建出全方位的治愈生态。

## ✨ 核心特性

### ⌚️ watchOS 端 (身心灵守护中心)
*   **HealthKit 情境感知 (Real-time Context)**：
    *   **压力/焦虑识别**：实时监测心率变异性 (HRV) 数据。当探测到交感神经异常活跃（HRV 跌破临界值）时，自动判定为高压焦灼态。
    *   **久坐/低活力识别**：后台追踪步数累积。当监测到长期静止（2小时内步数极低）时，判定为身体僵硬态。
*   **主动推送关怀 (Proactive Notifications)**：基于上述生理情境，应用会在后台自动唤醒，并从云端筛选出最贴合当下状态的治愈箴言（如：对焦虑者推送舒缓语句，对久坐者推送行动激励），通过 Taptic Engine 温柔震动并下发通知。
*   **原生光电伴随冥想 (`ReflectView`)**：60 秒沉浸式呼吸引导，光圈随呼吸节奏柔和缩放，搭配 4-4 触觉律动 (Haptics)。
*   **独立联网与分类语录**：手表端具备独立从 GitHub 拉取语录的能力。引言库已完全类别化（`calming`, `motivating`, `general`），确保关怀精准送达。

### 📱 iOS 端 (治愈中枢)
*   **动态流光美学**：主页采用深度定制的 `LinearGradient` 流体动画，搭配原生 `UltraThinMaterial` (毛玻璃) 构建出高级沉浸感 UI。
*   **全球双语支持**：应用原生支持 **中英双语** 自动切换。界面文案、引言库均会根据系统语言设置自动本地化适配。
*   **极简户外冥想提示**：利用极速 IP 定位匹配 `Open-Meteo` 天气系统，智能建议每日是否适合户外静心，全程无需向用户索要隐私定位权限。
*   **三级降级保护策略**：优先 GitHub 拉取 -> 本地缓存读取 -> 内嵌保底文案。

## 🛠️ 技术栈与架构
*   **iOS 17+ & watchOS 10+** (Swift & SwiftUI)
*   **HealthKit Background Delivery** 实现基于生理指标的后台监听。
*   **UserNotifications** 在 Watch 端独立分发本地即时通知。
*   **Observation Macro** (`@Observable`) 构建高效响应式数据流。
*   **String Catalog** (`.xcstrings`) 全面的多国语言管理。
*   **App Groups** 实现 iPhone 与 Watch 间的近端高速数据同步。

## 🚀 快速启动
1.  克隆或下载本仓库代码。
2.  在 Xcode 15+ 中打开 `SoulEcho.xcodeproj`。
3.  点击 **Signing & Capabilities** 登入个人 Apple ID，并确保勾选了 `App Groups` 和 `HealthKit` 权限。
4.  **真机测试建议**：为获得最佳体验，请将 App 部署至真实的 **Apple Watch (Series 10 推荐)**。首次运行请允许“健康数据获取”和“通知”权限。
5.  若在模拟器运行，系统会默认读取预设的演示数据。

---
*“无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。”* —— SoulEcho
