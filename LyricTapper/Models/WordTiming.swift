import Foundation

struct WordTiming: Identifiable, Codable, Equatable {
    let id: String
    let word: String
    let start: Double
    let end: Double
}


