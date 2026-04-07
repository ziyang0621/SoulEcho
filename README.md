# SoulEcho 🌿

SoulEcho 是一款专注于身心灵滋养和情绪记录的静心应用。通过极高美感的动态视觉与原生 Apple 硬件触感反馈的结合，为您带来随身的宁静与治愈体验。

目前项目包含 **iOS** 及 **watchOS** 两大组成部分，通过云端数据同步与原生 Apple `App Group` 构建出无缝的数据生态。

## ✨ 核心特性

### 📱 iOS 端 (治愈中枢)
*   **动态流光美学**：主页采用深度定制的 `LinearGradient` 流体动画，搭配原生 `UltraThinMaterial` (毛玻璃) 构建出高级沉浸感 UI。
*   **全球双语支持**：应用原生支持 **中英双语** 自动切换。界面文案、引言内容、作者信息均会根据系统语言设置自动适配。
*   **私有云端语录库**：通过 GitHub 仓库托管 `quotes.json`，实现语录库的实时更新。具备 **智能不重复轮换** 算法，优先为用户展示未曾读过的生命箴言。
*   **极简户外冥想提示**：利用极速 IP 定位匹配 `Open-Meteo` 天气系统，智能建议每日是否适合户外静心，全程无需向用户索要隐私定位权限。
*   **三级降级保护策略**：
    1. 优先从 GitHub 拉取最新云端语录。
    2. 网络不佳时自动读取手机本地缓存。
    3. 首次安装且断网时，使用内嵌的 5 句大师级保底引言。

### ⌚️ watchOS 端 (微型禅意中心)
*   **原生光电伴随冥想 (`ReflectView`)**：60 秒沉浸式呼吸引导，光圈随呼吸节奏柔和缩放。
*   **4-4 触觉律动 (Haptics)**：深度适配 Taptic Engine。吸气时发出轻微上升震感 (`directionUp`)，呼气时响应沉淀震感 (`directionDown`)，模拟真实的呼吸体感。
*   **独立联网能力**：手表端具备独立从 GitHub 拉取语录的能力，在模拟器或脱离 iPhone 的环境下依然能获得全新的引言。在真机环境下亦支持通过 App Group 同步 iPhone 的精选语录。

## 🛠️ 技术栈与架构
*   **iOS 17+ & watchOS 10+** (Swift & SwiftUI)
*   **Observation Macro** (`@Observable`) 构建高效响应式数据流。
*   **String Catalog** (`.xcstrings`) 管理多国语言，支持动态本地化。
*   **URLSession & JSONDecoder** 异步处理云端 JSON 数据。
*   **App Groups** 实现 iPhone 与 Watch 间的近端高速数据共享。

## 🚀 快速启动
1.  克隆或下载本仓库代码。
2.  在 Xcode 15+ 中打开 `SoulEcho.xcodeproj`。
3.  点击 **Signing & Capabilities** 登入个人 Apple ID。
4.  确保 **iOS App** 和 **Watch App** 的两个 Target 均已勾选 `App Groups`，且使用了您自己的组标识符（如：`group.com.yourname.SoulEcho`）。
5.  在 Xcode 顶栏分别选择真机或模拟器运行测试。

---
*“无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。”* —— SoulEcho
