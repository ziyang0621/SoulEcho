import Foundation

struct WatchQuote: Codable {
    let content: String
    let author: String
    
    enum CodingKeys: String, CodingKey {
        case content = "q"
        case author = "a"
    }
}

class WatchStorage {
    static let shared = WatchStorage()
    private let groupIdentifier = "group.com.ziyang.SoulEcho"
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: groupIdentifier) ?? UserDefaults.standard
    }
    
    func loadQuote() -> String {
        guard let data = userDefaults?.data(forKey: "saved_daily_quote"),
              let quote = try? JSONDecoder().decode(WatchQuote.self, from: data) else {
            return "无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。" // Fallback
        }
        return quote.content
    }
    
    func loadAuthor() -> String {
        guard let data = userDefaults?.data(forKey: "saved_daily_quote"),
              let quote = try? JSONDecoder().decode(WatchQuote.self, from: data) else {
            return "SoulEcho"
        }
        return quote.author
    }
}
