import SwiftUI
import AVFoundation
import AppKit

struct MergeExportView: View {
    @ObservedObject var app: AppState

    @State private var status: String = ""
    @State private var lyricOffsetMs: Int = 0
    @State private var imageOffsetMs: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Merge & Export Final").font(.title2)

            HStack(spacing: 12) {
                Stepper("Lyric Offset (ms): \(lyricOffsetMs)", value: $lyricOffsetMs, in: -5000...5000, step: 10)
                Stepper("Image Offset (ms): \(imageOffsetMs)", value: $imageOffsetMs, in: -5000...5000, step: 10)
                Spacer()
                Button("Export Final") { exportFinal() }
            }
            Text(status).foregroundColor(.secondary)
            Spacer()
        }
        .padding(24)
    }

    private func exportFinal() {
        guard let audioURL = resolveAudioURL() else { status = "Select accessible audio first"; return }
        // Offsets not yet applied in compositor; future step will shift intervals/timings non-destructively
        let settings = RenderSettings(fps: 30, width: 1080, height: 1920)
        let intervals = app.project.imageIntervals
        var lyricTake: TrackLyricTake? = app.projectV2.tracks.lyric.takes.first(where: { $0.id == app.projectV2.tracks.lyric.currentTakeId })
        // Fallback: if no current lyric take (or empty timings), build from v1 state
        if lyricTake == nil || (lyricTake?.timings.isEmpty == true) {
            lyricTake = makeLyricTakeFromV1()
        }
        status = "Exporting…"
        CompositorService.exportFinal(audioURL: audioURL, imageIntervals: intervals, settings: settings, lyricTake: lyricTake, lyricOffsetMs: lyricOffsetMs, imageOffsetMs: imageOffsetMs) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    status = "Exported: \(url.lastPathComponent)"
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                case .failure(let err):
                    status = "Export failed: \(err.localizedDescription)"
                }
            }
        }
    }

    private func makeLyricTakeFromV1() -> TrackLyricTake {
        TrackLyricTake(
            id: UUID().uuidString,
            name: "Lyric-Overlay",
            tapMode: (app.project.tapMode == .perSyllable ? .syllable : .word),
            tapTimestamps: app.project.taps.map { $0.t },
            timings: app.project.timings,
            fontFamily: app.project.exportSettings.fontFamily,
            fontFilePath: app.project.exportSettings.fontFilePath,
            fontSize: app.project.exportSettings.fontSizePct ?? 0.18,
            backgroundMode: .transparent,
            previewPath: nil
        )
    }

    private func resolveAudioURL() -> URL? {
        guard let data = app.project.audioPathBookmark, let url = BookmarkService.resolveBookmark(data) else { return nil }
        if url.startAccessingSecurityScopedResource() { return url }
        return nil
    }
}


