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

    // Tool mode
    var mode: ToolKind = .lyrics

    // Image Flash fields
    var imageFolderBookmark: Data? = nil
    var includeSubfolders: Bool = false
    var skipDuplicateImages: Bool = true
    var imageFileIDs: [ImageFileID] = []
    var imageCatalog: [ImageFileID: ImageMeta] = [:]
    var shuffleSeed: UInt64? = nil
    var imageTapTimestamps: [Double] = []
    var imageIntervals: [ImageInterval] = []
}

enum TapMode: String, Codable, Equatable { case perWord, perSyllable }

// MARK: - Image Flash Models

struct ImageFileID: Hashable, Codable {
    let urlBookmark: Data
}

struct ImageMeta: Codable, Equatable {
    let originalFilename: String
    let pixelWidth: Int
    let pixelHeight: Int
    let uti: String
    let fileSize: Int64?
    let fastHash: String?
}

struct ImageInterval: Codable, Equatable, Identifiable {
    var id: String { "\(fileID.urlBookmark.hashValue)-\(String(format: "%.3f", start))-\(String(format: "%.3f", end))" }
    var fileID: ImageFileID
    var start: Double
    var end: Double
}


