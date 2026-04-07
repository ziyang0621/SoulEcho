# SoulEcho 🌿

SoulEcho 是一款专注于身心灵滋养和情绪记录的静心应用。通过极高美感的动态视觉与原生 Apple 硬件触感反馈的结合，为您带来随身的宁静与治愈体验。

目前项目包含 **iOS** 及 **watchOS** 两大组成部分，并由一套原生 Apple `App Group` 构建出秒级的数据大一统生态。

## ✨ 核心特性

### 📱 iOS 端 (治愈中枢)
*   **动态流光美学**：主页采用深度定制的 `LinearGradient` 流体动画，搭配原生 `UltraThinMaterial` (毛玻璃) 构建出高级沉浸感 UI。
*   **深沉智慧引言**：无感知对接免密钥的 `ZenQuotes.io` API，每日拉取并呈现一句触动心灵的箴言，抚平一日的焦躁。
*   **极简户外冥想提示**：全网首创！不索要任何隐私定位权限，通过极速 IP 粗略解析映射匹配 `Open-Meteo` 天气系统，每日判断是否为您推荐“户外静心”。
*   **永不白屏降级策略**：基于 5 秒快速失败 (Fast-Fail) 机制，在任何苛刻网络或断网环境下，系统均会优雅退化，呈现预埋的治愈文案，体验丝般顺滑。

### ⌚️ watchOS 端 (微型禅意中心)
*   **原生光电伴随冥想 (`ReflectView`)**：点开这方屏幕，即可沉浸式进行为期 **60秒** 的身心放松。
*   **4-4 触觉律动 (Haptics)**：完美融合 Apple Watch 内部的 Taptic Engine（线性马达）。伴随着青色光圈的扩大（吸气）手腕传出极轻灵的 `Up` 级上升触震；缩小（呼气）则响应下沉沉淀的 `Down` 震动，直达心灵深处的共鸣。
*   **脱网秒读引言**：利用极致轻量化的底层重写，脱离 iPhone 的情况也会调用预载逻辑，并利用 App Group 全天候无缝接收 iPhone 捕获的最新引言。

## 🛠️ 技术栈与架构
*   **iOS 17+ & watchOS 10+** (Swift & SwiftUI)
*   **Observation Macro** (`@Observable`) 构建精准的响应式数据链
*   **URLSession & JSONDecoder** 原生非阻塞网络库
*   **App Groups** 原生近端高效率共享储存
*   **WKInterfaceDevice Haptics** 控制底座构建

## 🚀 快速启动
1.  克隆或下载本仓库代码。
2.  在 Xcode 15+ 中打开 `SoulEcho.xcodeproj`。
3.  点击上方 `Signing & Capabilities` 登入个人 Apple ID，确保 **iOS** 与 **watchOS** 两个 Target 都勾选启用了 `App Groups`，且组标识符互相匹配（默认推荐：`group.com.ziyang.SoulEcho`）。
4.  点选 `SoulEcho` Target 运行模拟器感受流光溢彩，随后点选 `SoulEcho Watch App` 验证两用生态闭环的魅力！

---
*“无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。”* —— SoulEcho
