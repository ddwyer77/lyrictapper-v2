import Foundation

struct WordToken: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let index: Int
    // Approximate syllable support
    let syllableCount: Int
    let hyphenBreaks: [Int] // character indices where syllables split
}


