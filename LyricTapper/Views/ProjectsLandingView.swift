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
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Projects").font(.headline)
                if app.projectManager.recent.isEmpty {
                    Text("No recent projects yet").foregroundColor(.secondary)
                } else {
                    List(app.projectManager.recent, id: \.self) { url in
                        HStack {
                            Text(url.lastPathComponent)
                            Spacer()
                            Button("Open") { app.projectManager.open(url: url); app.stage = .dashboard }
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                }
            }
            HStack(spacing: 12) {
                Button("Save Project As…") { saveProjectAs() }
                if let url = app.projectManager.currentURL { Text("Saving to: \(url.lastPathComponent)").foregroundColor(.secondary) }
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
                let p = try ProjectStore.loadV2(from: url)
                app.projectV2 = p
                app.projectManager.open(url: url)
                status = "Opened project (v2): \(url.lastPathComponent)"
                app.stage = .dashboard
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

    private func saveProjectAs() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = (app.projectV2.project.title.isEmpty ? "Untitled Project" : app.projectV2.project.title) + ".json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            app.projectManager.current = app.projectV2
            app.projectManager.save(to: url)
            status = "Saved: \(url.lastPathComponent)"
        }
    }
}


