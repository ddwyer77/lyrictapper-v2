import Foundation

enum ProjectStoreError: Error {
    case encoding
    case decoding
}

enum ProjectStore {
    // v1 legacy APIs (kept for backward compatibility with simple saves)
    static func saveV1(project: Project, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(project)
        try data.write(to: url)
    }

    static func loadV1(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Project.self, from: data)
    }

    // v2 APIs
    static func saveV2(project: ProjectV2, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(project)
        try data.write(to: url)
    }

    static func loadV2(from url: URL) throws -> ProjectV2 {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        // Try v2 first
        if let v2 = try? decoder.decode(ProjectV2.self, from: data) { return v2 }
        // Migrate v1 → v2
        let v1 = try decoder.decode(Project.self, from: data)
        return migrateV1ToV2(v1: v1)
    }

    static func migrateV1ToV2(v1: Project) -> ProjectV2 {
        var v2 = ProjectV2.newDefault(title: "Untitled Project")
        v2.audio.bookmark = v1.audioPathBookmark
        v2.audio.duration = v1.audioDuration
        v2.audio.sampleRate = 48000
        v2.audio.leadIn = Double(v1.offsetMs) / 1000.0

        // Create one lyric take from legacy data
        let take = TrackLyricTake(
            id: UUID().uuidString,
            name: "Lyric-Take-001",
            tapMode: (v1.tapMode == .perSyllable ? .syllable : .word),
            tapTimestamps: v1.taps.map { $0.t },
            timings: v1.timings,
            fontFamily: v1.exportSettings.fontFamily,
            fontFilePath: v1.exportSettings.fontFilePath,
            fontSize: v1.exportSettings.fontSizePct ?? 0.18,
            backgroundMode: .white,
            previewPath: nil
        )
        v2.tracks.lyric.takes = [take]
        v2.tracks.lyric.currentTakeId = take.id

        // Empty image track by default
        v2.tracks.image.takes = []
        v2.tracks.image.currentTakeId = nil

        // Carry global render settings
        v2.settings.fps = v1.exportSettings.fps
        v2.settings.width = v1.exportSettings.width
        v2.settings.height = v1.exportSettings.height

        return v2
    }
}


