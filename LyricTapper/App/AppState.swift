import Foundation
import SwiftUI
import AVFoundation

enum ToolKind: String, Codable, CaseIterable, Identifiable {
    case lyrics
    case imageFlash
    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    enum Stage: String, Codable, CaseIterable, Identifiable {
        case home
        case dashboard
        // Lyric tool stages
        case loadAudio
        case enterLyrics
        case tap
        case edit
        case export
        // Image Flash stages
        case loadImages
        case imageTap
        case imageEdit
        case imageExport
        case mergeExport
        var id: String { rawValue }
    }

    @Published var stage: Stage = .home
    @Published var activeTool: ToolKind = .lyrics
    @Published var project: Project
    @Published var waveform: [WaveformBin] = []
    @Published var showLogs: Bool = false
    @Published var logger: Logger = .shared

    // Keep a cached, security-scoped URL while in session
    private var scopedAudioURL: URL?

    init(now: Date = Date()) {
        let defaultSettings = ExportSettings(width: 1080, height: 1080, fps: 30, fontFamily: "Arial Narrow", fontFilePath: nil, fontSizePct: 0.18, textColor: "#000000")
        self.project = Project(
            id: UUID().uuidString,
            createdAt: ISO8601DateFormatter().string(from: now),
            updatedAt: ISO8601DateFormatter().string(from: now),
            audioPathBookmark: nil,
            audioDuration: 0,
            lyricsRaw: "",
            tokens: [],
            taps: [],
            timings: [],
            offsetMs: 0,
            exportSettings: defaultSettings
        )
        self.project.mode = .lyrics
    }

    func switchTool(_ tool: ToolKind) {
        activeTool = tool
        switch tool {
        case .lyrics:
            stage = .loadAudio
            project.mode = .lyrics
        case .imageFlash:
            stage = .loadImages
            project.mode = .imageFlash
        }
    }

    func updateLyrics(_ text: String) {
        project.lyricsRaw = text
        project.tokens = Tokenizer.tokenize(lyricsRaw: text)
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        logger.log(.info, "Lyrics updated", context: "tokens=\(project.tokens.count)")
    }

    func applyOffset(ms: Int) {
        project.offsetMs += ms
        recomputeTimings()
    }

    func setOffset(ms: Int) {
        project.offsetMs = ms
        recomputeTimings()
    }

    func setAudioDuration(seconds: Double) {
        project.audioDuration = max(0, seconds)
        recomputeTimings()
        logger.log(.info, "Audio duration set", context: String(format: "%.3fs", project.audioDuration))
    }

    func setTaps(_ taps: [Tap]) {
        project.taps = taps
        recomputeTimings()
        logger.log(.info, "Taps replaced", context: "count=\(taps.count)")
    }

    func pushTap(atSeconds seconds: Double) {
        project.taps.append(Tap(t: seconds))
        recomputeTimings()
        logger.log(.info, "Tap recorded", context: String(format: "t=%.3f", seconds))
    }

    func clearTaps() {
        project.taps.removeAll()
        project.timings.removeAll()
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        logger.log(.warn, "All taps cleared")
    }

    func recomputeTimings() {
        if project.tapMode == .perSyllable {
            project.timings = TimingService.computeTimingsPerSyllable(
                taps: project.taps,
                tokens: project.tokens,
                audioDuration: project.audioDuration,
                offsetMs: project.offsetMs
            )
        } else {
            project.timings = TimingService.computeTimings(
                taps: project.taps,
                tokens: project.tokens,
                audioDuration: project.audioDuration,
                offsetMs: project.offsetMs
            )
        }
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        logger.log(.info, "Timings recomputed", context: "timings=\(project.timings.count), offsetMs=\(project.offsetMs)")
    }
}

extension AppState {
    func setAudioBookmark(_ data: Data) {
        project.audioPathBookmark = data
        project.updatedAt = ISO8601DateFormatter().string(from: Date())
        // Invalidate prior scope
        if let url = scopedAudioURL { url.stopAccessingSecurityScopedResource() }
        if let url = BookmarkService.resolveBookmark(data), url.startAccessingSecurityScopedResource() {
            scopedAudioURL = url
        } else {
            scopedAudioURL = nil
        }
    }

    func computeWaveformIfPossible(targetBins: Int = 800) {
        var urlToUse: URL? = scopedAudioURL
        if urlToUse == nil, let data = project.audioPathBookmark, let resolved = BookmarkService.resolveBookmark(data), resolved.startAccessingSecurityScopedResource() {
            scopedAudioURL = resolved
            urlToUse = resolved
        }
        guard let url = urlToUse else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let bins = (try? WaveformService.computeRMSBins(url: url, targetBins: targetBins)) ?? []
            DispatchQueue.main.async { [weak self] in
                self?.waveform = bins
                self?.logger.log(.info, "Waveform computed", context: "bins=\(bins.count)")
            }
        }
    }
}


