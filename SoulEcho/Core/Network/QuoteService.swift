import Foundation
import Observation

@Observable
class QuoteService {
    var currentQuote: Quote?
    var isLoading = false
    var errorMessage: String?
    
    // GitHub 原始文件地址 — 您随时在 GitHub 上编辑 quotes.json 即可推送新内容
    private let remoteURL = "https://raw.githubusercontent.com/ziyang0621/SoulEcho/main/quotes.json"
    
    // 本地缓存 key
    private let cacheKey = "cached_quote_bank"
    private let seenIndicesKey = "seen_quote_indices"
    
    // 内嵌兜底（断网 + 首次安装时使用）
    private let fallbackQuotes = [
        Quote(content: "无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。", author: "SoulEcho"),
        Quote(content: "你不需要刻意去追寻平静，只需停止搅动这潭水。", author: "阿姜查"),
        Quote(content: "你的每一次呼吸，都是生命向你发出的最温柔的邀请。", author: "一行禅师"),
        Quote(content: "万物皆有裂痕，那是光照进来的地方。", author: "莱昂纳德·科恩"),
        Quote(content: "行到水穷处，坐看云起时。", author: "王维")
    ]
    
    func fetchTodayQuote() async {
        isLoading = true
        errorMessage = nil
        
        // 1. 尝试从 GitHub 拉取最新语录库
        var bank = await fetchRemoteBank()
        
        // 2. 如果网络失败，尝试读取本地缓存
        if bank == nil {
            bank = loadCachedBank()
        }
        
        // 3. 从语录库中智能选取一条未看过的
        let quotes = bank?.quotes ?? fallbackQuotes
        let selected = pickUnseenQuote(from: quotes)
        
        currentQuote = selected
        AppGroupManager.shared.saveQuote(selected)
        
        isLoading = false
    }
    
    // MARK: - 网络拉取
    
    private func fetchRemoteBank() async -> QuoteBank? {
        guard let url = URL(string: remoteURL) else { return nil }
        
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            let bank = try JSONDecoder().decode(QuoteBank.self, from: data)
            
            // 缓存到本地，下次断网也能用
            saveBankToCache(data)
            
            return bank
        } catch {
            print("Failed to fetch remote quotes: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 本地缓存 (UserDefaults)
    
    private func saveBankToCache(_ data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
    
    private func loadCachedBank() -> QuoteBank? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(QuoteBank.self, from: data)
    }
    
    // MARK: - 智能不重复轮换
    
    private func pickUnseenQuote(from quotes: [Quote]) -> Quote {
        guard !quotes.isEmpty else { return fallbackQuotes[0] }
        
        var seenIndices = UserDefaults.standard.array(forKey: seenIndicesKey) as? [Int] ?? []
        
        // 如果全部看完了，重置轮换
        if seenIndices.count >= quotes.count {
            seenIndices = []
        }
        
        // 找出所有还没看过的索引
        let allIndices = Set(0..<quotes.count)
        let unseenIndices = Array(allIndices.subtracting(seenIndices))
        
        // 随机选一个没看过的
        let chosenIndex = unseenIndices.randomElement()!
        seenIndices.append(chosenIndex)
        UserDefaults.standard.set(seenIndices, forKey: seenIndicesKey)
        
        return quotes[chosenIndex]
    }
}
