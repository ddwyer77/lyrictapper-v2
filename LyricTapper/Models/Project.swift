import Foundation

struct ExportSettings: Codable, Equatable {
    var width: Int
    var height: Int
    var fps: Int
    var fontFamily: String?
    var fontFilePath: String?
    var fontSizePct: Double? // relative to min(width, height)
    var textColor: String // hex like #000000
}

struct Tap: Codable, Equatable {
    let t: Double // seconds since 0
}

struct Project: Identifiable, Codable, Equatable {
    var id: String
    var createdAt: String
    var updatedAt: String

    // Store audio bookmark data for sandbox persistence
    var audioPathBookmark: Data?
    var audioDuration: Double

    var lyricsRaw: String
    var tokens: [WordToken]
    var taps: [Tap]
    var timings: [WordTiming]
    var offsetMs: Int

    var exportSettings: ExportSettings
    var tapMode: TapMode = .perWord
}

enum TapMode: String, Codable, Equatable { case perWord, perSyllable }


