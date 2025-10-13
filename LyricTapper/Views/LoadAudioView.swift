import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct LoadAudioView: View {
    @ObservedObject var app: AppState
    @State private var status: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Load Audio")
                .font(.title2)

            HStack(spacing: 12) {
                Button("Choose Audio…") { chooseAudio() }
                if app.project.audioDuration > 0 {
                    Text(String(format: "Duration: %.2f s", app.project.audioDuration))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Continue") { app.stage = .enterLyrics }
                    .disabled(app.project.audioDuration <= 0)
            }

            if !status.isEmpty {
                Text(status).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private func chooseAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.audio]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let bookmark = try BookmarkService.createBookmark(for: url)
                app.project.audioPathBookmark = bookmark

                let asset = AVAsset(url: url)
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                app.setAudioDuration(seconds: durationSeconds)
                status = "Loaded audio (\(String(format: "%.2f", durationSeconds)) s)"
            } catch {
                status = "Failed: \(error.localizedDescription)"
            }
        }
    }
}


