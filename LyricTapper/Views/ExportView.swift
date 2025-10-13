import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import AVKit

struct ExportView: View {
    @ObservedObject var app: AppState

    @State private var previewStatus: String = ""
    @State private var sizePreset: SizePreset = .square
    @State private var showFontPicker: Bool = false
    @State private var previewPlayer: AVPlayer? = nil

    enum SizePreset: String, CaseIterable, Identifiable {
        case horizontal169
        case square
        case vertical916
        var id: String { rawValue }
        var label: String {
            switch self { case .horizontal169: return "Horizontal 16:9"; case .square: return "Square 1:1"; case .vertical916: return "Vertical 9:16" }
        }
        func dimensions(base: Int = 1080) -> (Int, Int) {
            switch self {
            case .horizontal169:
                let width = base
                let height = Int((Double(base) / 16.0) * 9.0)
                return (width, height)
            case .square:
                return (base, base)
            case .vertical916:
                let width = Int((Double(base) / 16.0) * 9.0)
                let height = base
                return (width, height)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview and Export")
                .font(.title2)

            HStack(spacing: 12) {
                Picker("Size", selection: $sizePreset) {
                    ForEach(SizePreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Menu("Font") {
                    Button("Arial Narrow") { app.project.exportSettings.fontFamily = "Arial Narrow" }
                    Button("System Default") { app.project.exportSettings.fontFamily = nil }
                    Divider()
                    Button("Choose System Font…") { showFontPicker = true }
                    Button("Import TTF/OTF…") { importCustomFont() }
                }

                Button("Render Preview") { renderPreview() }
                Button("Export MP4") { exportFinal() }
                Spacer()
                Text(previewStatus).foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Text("Font:")
                    .foregroundColor(.secondary)
                Text(app.project.exportSettings.fontFamily ?? "System")
                Button("Choose…") { showFontPicker = true }
                Button("Import…") { importCustomFont() }
                Spacer()
            }
            Divider()
            Group {
                if let player = previewPlayer {
                    GeometryReader { geo in
                        let targetAspect = CGFloat(max(1, app.project.exportSettings.width)) / CGFloat(max(1, app.project.exportSettings.height))
                        let width = geo.size.width
                        let height = min(geo.size.height, width / targetAspect)
                        PlayerView(player: player)
                            .frame(width: width, height: height)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    }
                    .frame(minHeight: 320)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.windowBackgroundColor))
                        Text("Render Preview to see a video here")
                            .foregroundColor(.secondary)
                    }
                    .frame(minHeight: 220)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                }
            }
        }
        .padding()
        .sheet(isPresented: $showFontPicker) {
            SystemFontPickerView(onPick: { family in
                app.project.exportSettings.fontFamily = family
                app.logger.log(.info, "Font selected", context: family)
                showFontPicker = false
            }, onCancel: {
                showFontPicker = false
            })
            .frame(minWidth: 420, minHeight: 520)
        }
    }

    private func renderPreview() {
        guard let audioURL = resolveAudioURL() else {
            previewStatus = "Select accessible audio file first."
            return
        }
        app.logger.log(.info, "Resolve audio URL for export", context: audioURL.path)
        applyPresetToSettings()
        ExportService.renderPreviewFile(audioURL: audioURL, timings: app.project.timings, settings: app.project.exportSettings) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    previewStatus = "Preview composition created."
                    app.logger.log(.info, "Preview file ready", context: url.lastPathComponent)
                    previewPlayer = AVPlayer(url: url)
                case .failure(let error):
                    previewStatus = "Preview failed: \(error.localizedDescription)"
                    app.logger.log(.error, "Preview failed", context: error.localizedDescription)
                }
            }
        }
    }

    private func exportFinal() {
        guard let audioURL = resolveAudioURL() else {
            previewStatus = "Select accessible audio file first."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "lyric_tapper.mp4"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            previewStatus = "Exporting…"
            applyPresetToSettings()
            ExportService.export(audioURL: audioURL, timings: app.project.timings, settings: app.project.exportSettings, destinationURL: url) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        previewStatus = "Exported: \(url.lastPathComponent)"
                        app.logger.log(.info, "Export succeeded", context: url.lastPathComponent)
                    case .failure(let error):
                        previewStatus = "Export failed: \(error.localizedDescription)"
                        app.logger.log(.error, "Export failed", context: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func resolveAudioURL() -> URL? {
        guard let data = app.project.audioPathBookmark, let url = BookmarkService.resolveBookmark(data) else { return nil }
        if url.startAccessingSecurityScopedResource() {
            return url
        }
        return nil
    }

    private func applyPresetToSettings() {
        let (w, h) = sizePreset.dimensions()
        app.project.exportSettings.width = w
        app.project.exportSettings.height = h
        app.logger.log(.info, "Export size set", context: "\(w)x\(h)")
    }

    private func importCustomFont() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["ttf", "otf"]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            app.project.exportSettings.fontFilePath = url.path
            app.project.exportSettings.fontFamily = nil
            app.logger.log(.info, "Custom font imported", context: url.lastPathComponent)
        }
    }
}


