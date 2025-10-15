import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ProjectsLandingView: View {
    @ObservedObject var app: AppState

    @State private var status: String = ""
    @State private var pickedAudioURL: URL? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Lyric Tapper")
                .font(.largeTitle)

            VStack(spacing: 12) {
                Button("New Project – Choose Audio…") { chooseAudio() }
                if let url = pickedAudioURL {
                    Text("Audio: \(url.lastPathComponent)")
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    Button("Start with Lyric Tool") { startWith(.lyrics) }
                        .disabled(pickedAudioURL == nil)
                    Button("Start with Image Flash") { startWith(.imageFlash) }
                        .disabled(pickedAudioURL == nil)
                }
            }

            Divider().padding(.vertical, 8)

            HStack(spacing: 12) {
                Button("Open Project…") { openLegacyOrV2() }
                Text(status).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(24)
    }

    private func chooseAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.audio]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            pickedAudioURL = url
            status = "Picked audio: \(url.lastPathComponent)"
        }
    }

    private func startWith(_ tool: ToolKind) {
        guard let url = pickedAudioURL else { return }
        do {
            let bookmark = try BookmarkService.createBookmark(for: url)
            app.setAudioBookmark(bookmark)
            let asset = AVAsset(url: url)
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            app.setAudioDuration(seconds: durationSeconds)
            // Initialize v2 project audio metadata
            app.projectV2.audio.bookmark = bookmark
            app.projectV2.audio.duration = durationSeconds
            app.projectV2.audio.sampleRate = 48000
            app.projectV2.settings.fps = 30
            app.projectV2.settings.width = 1080
            app.projectV2.settings.height = 1920
            app.stage = .dashboard
        } catch {
            status = "Failed: \(error.localizedDescription)"
        }
    }

    private func openLegacyOrV2() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json", "ltproj", "ltproj.json"]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                // Try v2 first
                _ = try ProjectStore.loadV2(from: url)
                status = "Opened project (v2): \(url.lastPathComponent)"
            } catch {
                // Fallback to v1 legacy
                if let v1 = try? ProjectStore.loadV1(from: url) {
                    if let data = v1.audioPathBookmark, let resolved = BookmarkService.resolveBookmark(data) {
                        app.setAudioBookmark(data)
                        let asset = AVAsset(url: resolved)
                        app.setAudioDuration(seconds: CMTimeGetSeconds(asset.duration))
                        app.switchTool(.lyrics)
                        status = "Opened legacy project"
                    }
                } else {
                    status = "Open failed: \(error.localizedDescription)"
                }
            }
        }
    }
}


