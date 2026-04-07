import Foundation
import Observation

@Observable
class QuoteService {
    var currentQuote: Quote?
    var isLoading = false
    var errorMessage: String?
    
    func fetchTodayQuote() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "https://zenquotes.io/api/today") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            let quotes = try JSONDecoder().decode([Quote].self, from: data)
            currentQuote = quotes.first
            
            if let quote = quotes.first {
                AppGroupManager.shared.saveQuote(quote)
            }
        } catch {
            errorMessage = "Failed to load quote: \(error.localizedDescription)"
            if let cached = AppGroupManager.shared.loadQuote() {
                currentQuote = cached
            } else {
                currentQuote = Quote(content: "无论你在此刻感到何种情绪，允许它的存在，并安静地与之共处。", author: "SoulEcho")
            }
        }
        
        isLoading = false
    }
}
