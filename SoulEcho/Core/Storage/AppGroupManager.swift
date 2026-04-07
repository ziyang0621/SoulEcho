import Foundation

class AppGroupManager {
    static let shared = AppGroupManager()
    
    // REPLACE with actual App Group ID from Developer Portal later
    private let groupIdentifier = "group.com.ziyang.SoulEcho"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: groupIdentifier) ?? UserDefaults.standard
    }
    
    private let quoteKey = "saved_daily_quote"
    
    func saveQuote(_ quote: Quote) {
        if let data = try? JSONEncoder().encode(quote) {
            userDefaults?.set(data, forKey: quoteKey)
        }
    }
    
    func loadQuote() -> Quote? {
        guard let data = userDefaults?.data(forKey: quoteKey) else { return nil }
        return try? JSONDecoder().decode(Quote.self, from: data)
    }
}
