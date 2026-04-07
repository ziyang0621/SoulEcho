import Foundation

struct WatchQuote: Codable {
    let content: String
    let author: String
}

struct WatchLocalizedEntry: Codable {
    let contentZh: String
    let authorZh: String
    let contentEn: String
    let authorEn: String
    
    enum CodingKeys: String, CodingKey {
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
        WatchLocalizedEntry(
            contentZh: "无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。", authorZh: "SoulEcho",
            contentEn: "Whatever emotion you feel right now, allow it to exist. Sit quietly with it.", authorEn: "SoulEcho"
        ),
        WatchLocalizedEntry(
            contentZh: "你不需要刻意去追寻平静，只需停止搅动这潭水。", authorZh: "阿姜查",
            contentEn: "You don't need to try to be peaceful. Just stop stirring the water.", authorEn: "Ajahn Chah"
        )
    ]
    
    // MARK: - 主入口：拉取并返回一条新语录
    
    func fetchFreshQuote() async -> WatchQuote {
        // 1. 尝试网络拉取
        if let bank = await fetchRemoteBank() {
            let entry = pickUnseenEntry(from: bank.quotes)
            return entry.toQuote()
        }
        
        // 2. 尝试读取 App Group（真机上 iPhone 可能已写入）
        if let appGroupQuote = loadFromAppGroup() {
            return appGroupQuote
        }
        
        // 3. 尝试读取本地缓存
        if let cached = loadCachedBank() {
            let entry = pickUnseenEntry(from: cached.quotes)
            return entry.toQuote()
        }
        
        // 4. 最终兜底
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
    
    private func pickUnseenEntry(from entries: [WatchLocalizedEntry]) -> WatchLocalizedEntry {
        guard !entries.isEmpty else { return fallbackEntries[0] }
        
        var seenIndices = UserDefaults.standard.array(forKey: seenIndicesKey) as? [Int] ?? []
        
        if seenIndices.count >= entries.count {
            seenIndices = []
        }
        
        let allIndices = Set(0..<entries.count)
        let unseenIndices = Array(allIndices.subtracting(seenIndices))
        
        let chosenIndex = unseenIndices.randomElement()!
        seenIndices.append(chosenIndex)
        UserDefaults.standard.set(seenIndices, forKey: seenIndicesKey)
        
        return entries[chosenIndex]
    }
}
