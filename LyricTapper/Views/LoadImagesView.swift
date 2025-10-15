import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct LoadImagesView: View {
    @ObservedObject var app: AppState
    @State private var status: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Load Images")
                .font(.title2)

            HStack(spacing: 12) {
                Button("Choose Audio…") { chooseAudio() }
                if app.project.audioDuration > 0 {
                    Text(String(format: "Duration: %.2f s", app.project.audioDuration))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Choose Folder…") { chooseFolder() }
                Toggle("Include subfolders", isOn: $app.project.includeSubfolders)
                Toggle("Skip duplicate images", isOn: $app.project.skipDuplicateImages)
            }

            HStack(spacing: 12) {
                Text(status).foregroundColor(.secondary)
                Spacer()
                Button("Continue") { app.stage = .imageTap }
                    .disabled(app.project.audioDuration <= 0 || app.project.imageCatalog.isEmpty)
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
            } catch { }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let bookmark = try BookmarkService.createBookmark(for: url)
                app.project.imageFolderBookmark = bookmark
                // Save to v2 current image take (create if needed)
                if app.projectV2.tracks.image.takes.isEmpty {
                    let t = TrackImageTake(id: UUID().uuidString, name: "Image-Take-001", imageFolderBookmark: bookmark, includeSubfolders: app.project.includeSubfolders, skipDuplicateImages: app.project.skipDuplicateImages, imageCatalog: [:], shuffleSeed: 0, chosenOrder: [], tapTimestamps: [], intervals: [], previewPath: nil)
                    app.projectV2.tracks.image.takes = [t]
                    app.projectV2.tracks.image.currentTakeId = t.id
                } else if let id = app.projectV2.tracks.image.currentTakeId, let idx = app.projectV2.tracks.image.takes.firstIndex(where: { $0.id == id }) {
                    app.projectV2.tracks.image.takes[idx].imageFolderBookmark = bookmark
                    app.projectV2.tracks.image.takes[idx].includeSubfolders = app.project.includeSubfolders
                    app.projectV2.tracks.image.takes[idx].skipDuplicateImages = app.project.skipDuplicateImages
                }
                let result = ImageSequenceService.buildCatalog(folderBookmark: bookmark, includeSubfolders: app.project.includeSubfolders, skipDuplicates: app.project.skipDuplicateImages, logger: app.logger)
                app.project.imageCatalog = result.catalog
                // Seed and order
                let seed = UInt64.random(in: 1...UInt64.max)
                app.project.shuffleSeed = seed
                let keys = Array(result.catalog.keys)
                app.project.imageFileIDs = ImageSequenceService.shuffleBagOrder(items: keys, seed: seed)
                status = "Folder selected: \(url.lastPathComponent). Images: \(result.catalog.count)"
                // Persist catalog and order
                if let id = app.projectV2.tracks.image.currentTakeId, let idx = app.projectV2.tracks.image.takes.firstIndex(where: { $0.id == id }) {
                    app.projectV2.tracks.image.takes[idx].imageCatalog = result.catalog
                    let seed = app.project.shuffleSeed ?? 0
                    app.projectV2.tracks.image.takes[idx].shuffleSeed = seed
                    app.projectV2.tracks.image.takes[idx].chosenOrder = app.project.imageFileIDs
                }
            } catch {
                status = "Failed: \(error.localizedDescription)"
            }
        }
    }
}


