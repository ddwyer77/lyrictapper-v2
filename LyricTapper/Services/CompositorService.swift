import Foundation
import AVFoundation

enum CompositorService {
    // Placeholder final export that currently mirrors image export; overlay integration to follow
    static func exportFinal(
        audioURL: URL,
        imageIntervals: [ImageInterval],
        settings: RenderSettings,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                let dest = tempDir.appendingPathComponent("final_merged_\(UUID().uuidString).mp4")
                // Reuse image flash renderer by adapting settings
                // Convert RenderSettings -> ExportSettings for reuse
                let exportSettings = ExportSettings(
                    width: settings.width,
                    height: settings.height,
                    fps: settings.fps,
                    fontFamily: nil,
                    fontFilePath: nil,
                    fontSizePct: 0.18,
                    textColor: "#000000"
                )
                // Create a temporary video from images only, then mux audio
                let tmpVideo = tempDir.appendingPathComponent("image_only_\(UUID().uuidString).mp4")
                try ExportService_renderImageTimeline(to: tmpVideo, audioURL: audioURL, intervals: imageIntervals, settings: exportSettings)
                try muxAudioVideo(audioURL: audioURL, videoURL: tmpVideo, destinationURL: dest)
                completion(.success(dest))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// Internal helper bridging to existing private functions
private func ExportService_renderImageTimeline(to url: URL, audioURL: URL, intervals: [ImageInterval], settings: ExportSettings) throws {
    // Call the image flash writer used by ExportService
    try renderImageFlashVideoOnly(to: url, audioURL: audioURL, intervals: intervals, width: settings.width, height: settings.height, fps: settings.fps)
}


