import Foundation

struct Quote: Codable, Equatable {
    let content: String
    let author: String
    
    enum CodingKeys: String, CodingKey {
        case content = "q"
        case author = "a"
    }
}
