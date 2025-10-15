import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioTrimView: View {
    @ObservedObject var app: AppState

    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var status: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trim Audio").font(.title2)
            Text("Select a start and end time to create a trimmed copy. Your project will switch to use the trimmed file.").foregroundColor(.secondary)
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(String(format: "Start: %.2fs", startTime))
                    Slider(value: $startTime, in: 0...max(0,endTime-0.1), step: 0.01)
                }
                VStack(alignment: .leading) {
                    Text(String(format: "End: %.2fs", endTime))
                    Slider(value: $endTime, in: max(startTime+0.1, 0)...max(startTime+0.1, app.project.audioDuration), step: 0.01)
                }
            }
            HStack(spacing: 12) {
                Button("Use Full Audio") { skipTrim() }
                Button("Trim & Use Copy") { trimAndUse() }
                Spacer()
                Button("Continue") { app.stage = .enterLyrics }
            }
            Text(status).foregroundColor(.secondary)
            Spacer()
        }
        .padding(24)
        .onAppear { initializeBounds() }
    }

    private func initializeBounds() {
        let dur = app.project.audioDuration
        startTime = 0
        endTime = max(0.1, dur)
    }

    private func skipTrim() {
        app.stage = .enterLyrics
    }

    private func trimAndUse() {
        guard let audioURL = resolveAudioURL() else { status = "Audio not accessible"; return }
        let s = max(0, min(startTime, endTime - 0.1))
        let e = max(s + 0.1, endTime)
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("trim_\(UUID().uuidString).m4a")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try exportTrimmedAudio(source: audioURL, start: s, end: e, to: outURL)
                let bm = try BookmarkService.createBookmark(for: outURL)
                DispatchQueue.main.async {
                    app.setAudioBookmark(bm)
                    app.setAudioDuration(seconds: e - s)
                    status = "Trimmed and switched to new audio"
                }
            } catch {
                DispatchQueue.main.async { status = "Trim failed: \(error.localizedDescription)" }
            }
        }
    }

    private func resolveAudioURL() -> URL? {
        guard let data = app.project.audioPathBookmark, let url = BookmarkService.resolveBookmark(data) else { return nil }
        if url.startAccessingSecurityScopedResource() { return url }
        return nil
    }
}

private func exportTrimmedAudio(source: URL, start: Double, end: Double, to dest: URL) throws {
    let asset = AVAsset(url: source)
    guard let track = asset.tracks(withMediaType: .audio).first else { throw ExportServiceError.missingAudio }
    let composition = AVMutableComposition()
    let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let startTime = CMTime(seconds: start, preferredTimescale: 600)
    let duration = CMTime(seconds: end - start, preferredTimescale: 600)
    try compAudio.insertTimeRange(CMTimeRange(start: startTime, duration: duration), of: track, at: .zero)

    if FileManager.default.fileExists(atPath: dest.path) { try? FileManager.default.removeItem(at: dest.path) }
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else { throw ExportServiceError.compositionFailed }
    exporter.outputURL = dest
    exporter.outputFileType = .m4a
    let g = DispatchGroup(); var err: Error?; g.enter()
    exporter.exportAsynchronously { if exporter.status != .completed { err = exporter.error ?? ExportServiceError.compositionFailed }; g.leave() }
    g.wait()
    if let e = err { throw e }
}
