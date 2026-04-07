import Foundation
import Observation

struct LocalizedQuoteEntry: Codable {
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
    
    func toQuote() -> Quote {
        let isChinese = Locale.current.language.languageCode?.identifier == "zh"
        if isChinese {
            return Quote(content: contentZh, author: authorZh)
        } else {
            return Quote(content: contentEn, author: authorEn)
        }
    }
}

struct QuoteBank: Codable {
    let version: Int
    let quotes: [LocalizedQuoteEntry]
}

@Observable
class QuoteService {
    var currentQuote: Quote?
    var isLoading = false
    var errorMessage: String?
    
    // GitHub 原始文件地址
    private let remoteURL = "https://raw.githubusercontent.com/ziyang0621/SoulEcho/main/quotes.json"
    
    // 本地缓存 key
    private let cacheKey = "cached_quote_bank"
    private let seenIndicesKey = "seen_quote_indices"
    
    // 内嵌兜底双语（断网 + 首次安装时使用）
    private let fallbackQuotes = [
        LocalizedQuoteEntry(
            contentZh: "无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。", authorZh: "SoulEcho",
            contentEn: "Whatever emotion you feel right now, allow it to exist. Sit quietly with it for a moment.", authorEn: "SoulEcho"
        ),
        LocalizedQuoteEntry(
            contentZh: "你不需要刻意去追寻平静，只需停止搅动这潭水。", authorZh: "阿姜查",
            contentEn: "You don't need to try to be peaceful. Just stop trying to control the water.", authorEn: "Ajahn Chah"
        )
    ]
    
    func fetchTodayQuote() async {
        isLoading = true
        errorMessage = nil
        
        // 1. 尝试从 GitHub 拉取最新双语语录库
        var bank = await fetchRemoteBank()
        
        // 2. 如果网络失败，尝试读取本地缓存
        if bank == nil {
            bank = loadCachedBank()
        }
        
        // 3. 从语录库中智能选取一条未看过的
        let entry = pickUnseenQuoteEntry(from: bank?.quotes ?? fallbackQuotes)
        
        // 4. 根据当前系统语言转化
        let localizedQuote = entry.toQuote()
        
        currentQuote = localizedQuote
        AppGroupManager.shared.saveQuote(localizedQuote)
        
        isLoading = false
    }
    
    // MARK: - 网络拉取
    
    private func fetchRemoteBank() async -> QuoteBank? {
        guard let url = URL(string: remoteURL) else { return nil }
        
        do {
            let config = URLSessionConfiguration.default
            // 为了防止卡主，设置5秒超时
            config.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            let bank = try JSONDecoder().decode(QuoteBank.self, from: data)
            
            saveBankToCache(data)
            return bank
        } catch {
            print("Failed to fetch remote quotes: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 本地缓存
    
    private func saveBankToCache(_ data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
    
    private func loadCachedBank() -> QuoteBank? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(QuoteBank.self, from: data)
    }
    
    // MARK: - 智能不重复轮换
    
    private func pickUnseenQuoteEntry(from quotes: [LocalizedQuoteEntry]) -> LocalizedQuoteEntry {
        guard !quotes.isEmpty else { return fallbackQuotes[0] }
        
        var seenIndices = UserDefaults.standard.array(forKey: seenIndicesKey) as? [Int] ?? []
        
        if seenIndices.count >= quotes.count {
            seenIndices = [] // 看完一轮后重置
        }
        
        let allIndices = Set(0..<quotes.count)
        let unseenIndices = Array(allIndices.subtracting(seenIndices))
        
        let chosenIndex = unseenIndices.randomElement()!
        seenIndices.append(chosenIndex)
        UserDefaults.standard.set(seenIndices, forKey: seenIndicesKey)
        
        return quotes[chosenIndex]
    }
}
