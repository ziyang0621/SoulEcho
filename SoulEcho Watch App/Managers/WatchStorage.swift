import Foundation

struct WatchQuote: Codable {
    let content: String
    let author: String
}

struct WatchLocalizedEntry: Codable {
    let category: String?
    let contentZh: String
    let authorZh: String
    let contentEn: String
    let authorEn: String
    
    enum CodingKeys: String, CodingKey {
        case category
        case contentZh = "content_zh"
        case authorZh = "author_zh"
        case contentEn = "content_en"
        case authorEn = "author_en"
    }
    
    func toQuote() -> WatchQuote {
        let isChinese = Locale.current.language.languageCode?.identifier == "zh"
        if isChinese {
            return WatchQuote(content: contentZh, author: authorZh)
        } else {
            return WatchQuote(content: contentEn, author: authorEn)
        }
    }
}

struct WatchQuoteBank: Codable {
    let version: Int
    let quotes: [WatchLocalizedEntry]
}

class WatchStorage {
    static let shared = WatchStorage()
    private let groupIdentifier = "group.com.ziyang.SoulEcho"
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: groupIdentifier) ?? UserDefaults.standard
    }
    
    private let remoteURL = "https://raw.githubusercontent.com/ziyang0621/SoulEcho/main/quotes.json"
    private let cacheKey = "watch_cached_quote_bank"
    private let seenIndicesKey = "watch_seen_quote_indices"
    
    // 内嵌兜底
    private let fallbackEntries = [
        WatchLocalizedEntry(category: "calming",
            contentZh: "无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。", authorZh: "SoulEcho",
            contentEn: "Whatever emotion you feel right now, allow it to exist. Sit quietly with it.", authorEn: "SoulEcho"
        ),
        WatchLocalizedEntry(category: "calming",
            contentZh: "你不需要刻意去追寻平静，只需停止搅动这潭水。", authorZh: "阿姜查",
            contentEn: "You don't need to try to be peaceful. Just stop stirring the water.", authorEn: "Ajahn Chah"
        )
    ]
    
    // MARK: - 主入口：拉取并返回一条新语录
    
    func fetchFreshQuote(for category: String? = nil) async -> WatchQuote {
        // 1. 尝试网络拉取
        if let bank = await fetchRemoteBank() {
            let entry = pickUnseenEntry(from: bank.quotes, category: category)
            return entry.toQuote()
        }
        
        return fetchFastLocalQuote(for: category)
    }
    
    // MARK: - 快速本地读取（用于防挂起）
    
    func fetchFastLocalQuote(for category: String? = nil) -> WatchQuote {
        // 1. 优先使用本地缓存库（支持随机不重复）
        if let cached = loadCachedBank() {
            let entry = pickUnseenEntry(from: cached.quotes, category: category)
            return entry.toQuote()
        }
        
        // 2. 尝试读取 App Group（iPhone 写入的每日一句）
        if let appGroupQuote = loadFromAppGroup() {
            return appGroupQuote
        }
        
        // 3. 最终兜底：随机选一条
        let entry = fallbackEntries.randomElement()!
        return entry.toQuote()
    }
    
    // MARK: - 兼容旧接口（供 onAppear 同步调用）
    
    func loadQuote() -> String {
        if let q = loadFromAppGroup() { return q.content }
        return fallbackEntries[0].toQuote().content
    }
    
    func loadAuthor() -> String {
        if let q = loadFromAppGroup() { return q.author }
        return fallbackEntries[0].toQuote().author
    }
    
    // MARK: - App Group 读取
    
    private func loadFromAppGroup() -> WatchQuote? {
        guard let data = userDefaults?.data(forKey: "saved_daily_quote"),
              let quote = try? JSONDecoder().decode(WatchQuote.self, from: data) else {
            return nil
        }
        return quote
    }
    
    // MARK: - 网络拉取
    
    private func fetchRemoteBank() async -> WatchQuoteBank? {
        guard let url = URL(string: remoteURL) else { return nil }
        
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            let bank = try JSONDecoder().decode(WatchQuoteBank.self, from: data)
            
            // 缓存到本地
            UserDefaults.standard.set(data, forKey: cacheKey)
            
            return bank
        } catch {
            print("[Watch] Failed to fetch quotes: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 本地缓存
    
    private func loadCachedBank() -> WatchQuoteBank? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(WatchQuoteBank.self, from: data)
    }
    
    // MARK: - 智能不重复轮换
    
    func pickUnseenEntry(from allEntries: [WatchLocalizedEntry], category: String? = nil) -> WatchLocalizedEntry {
        var entries = allEntries
        if let category = category {
            let filtered = entries.filter { $0.category == category }
            if !filtered.isEmpty { entries = filtered }
        }
        
        guard !entries.isEmpty else { return fallbackEntries[0] }
        
        var seenIndices = UserDefaults.standard.array(forKey: seenIndicesKey) as? [Int] ?? []
        
        if seenIndices.count >= allEntries.count {
            seenIndices = []
        }
        
        // 我们只在筛选后的 entries 中找，由于 indices 需要在全集中查，所以我们做内容比对或者重新索引
        // 为了简便且支持分类过滤，我们在当前 filtered entries 中寻找没被查阅过的
        // 这里需要一个小小的技巧：我们可以把 content 存进去作为看过，而不是 Index，不过这里仅为演示，继续简化处理
        let filteredUnseen = entries.filter { entry in
            let indexInAll = allEntries.firstIndex(where: { $0.contentZh == entry.contentZh }) ?? 0
            return !seenIndices.contains(indexInAll)
        }
        
        let pool = filteredUnseen.isEmpty ? entries : filteredUnseen
        let chosenEntry = pool.randomElement()!
        
        if let idx = allEntries.firstIndex(where: { $0.contentZh == chosenEntry.contentZh }) {
            seenIndices.append(idx)
            UserDefaults.standard.set(seenIndices, forKey: seenIndicesKey)
        }
        
        return chosenEntry
    }
}
