import Foundation

struct Quote: Codable, Equatable {
    var content: String
    var author: String
}

struct QuoteBank: Codable {
    let version: Int
    let quotes: [Quote]
}
