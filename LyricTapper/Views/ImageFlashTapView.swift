import SwiftUI
import AppKit
import CoreGraphics

struct ImageFlashTapView: View {
    @ObservedObject var app: AppState
    @StateObject var audio = AudioService()
    @State private var currentIndex: Int = 0
    @State private var decodeCache = ImageDecodeCache()

    private func resolveURL(for id: ImageFileID) -> URL? {
        BookmarkService.resolveBookmark(id.urlBookmark)
    }

    private var currentImage: CGImage? {
        guard !app.project.imageFileIDs.isEmpty else { return nil }
        let id = app.project.imageFileIDs[currentIndex % app.project.imageFileIDs.count]
        guard let url = resolveURL(for: id) else { return nil }
        return decodeCache.decodedScaledToWidth(url: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KeyCaptureView {
                if audio.isPlaying {
                    let t = audio.currentTimeSeconds()
                    app.project.imageTapTimestamps.append(t)
                    currentIndex += 1
                    preloadLookahead()
                } else {
                    do { try audio.toggle() } catch { }
                }
            } onRestart: {
                audio.resetToStart()
                app.project.imageTapTimestamps.removeAll()
                currentIndex = 0
            } onFinish: {
                app.stage = .imageEdit
            }
            .background(Color.clear)
            .allowsHitTesting(false)

            HStack(spacing: 12) {
                Button(audio.isPlaying ? "Pause" : "Play") {
                    do {
                        try audio.toggle()
                        if audio.isPlaying == false {
                            // If toggle failed to start, try reloading the file
                            if let data = app.project.audioPathBookmark, let url = BookmarkService.resolveBookmark(data) {
                                do { try audio.loadFile(url: url) } catch { }
                            }
                        }
                    } catch { }
                }
                Button("Restart Take (R)") {
                    audio.resetToStart()
                    app.project.imageTapTimestamps.removeAll()
                    currentIndex = 0
                }
                Spacer()
                Button("Continue to Edit") {
                    app.project.imageIntervals = TimingService.computeImageIntervals(
                        taps: app.project.imageTapTimestamps,
                        audioDuration: app.project.audioDuration,
                        imageOrder: app.project.imageFileIDs
                    )
                    app.stage = .imageEdit
                }
            }
            .padding(.top, 8)

            ZStack {
                Rectangle().fill(Color.black)
                if let cg = currentImage {
                    GeometryReader { geo in
                        let canvasW: CGFloat = geo.size.width
                        let canvasH: CGFloat = min(geo.size.height, canvasW * (16.0/9.0))
                        let scale = canvasW / CGFloat(cg.width)
                        let destH = CGFloat(cg.height) * scale
                        let y = (canvasH - destH) / 2.0
                        CGContextImageView(cgImage: cg)
                            .frame(width: canvasW, height: destH)
                            .position(x: canvasW / 2.0, y: y + destH / 2.0)
                    }
                } else {
                    Text("Select a folder with images to begin.")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 480)
            .clipped()

            if !app.waveform.isEmpty {
                WaveformScrubView(app: app, audio: audio)
                    .frame(height: 160)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .onAppear {
            if let data = app.project.audioPathBookmark,
               let url = BookmarkService.resolveBookmark(data),
               url.startAccessingSecurityScopedResource() {
                do {
                    try audio.loadFile(url: url)
                    app.setAudioDuration(seconds: audio.duration)
                    app.computeWaveformIfPossible()
                    preloadLookahead()
                } catch { }
            }
        }
    }

    private func preloadLookahead() {
        let ids = app.project.imageFileIDs
        guard !ids.isEmpty else { return }
        let lookahead = (1...8).compactMap { offset -> URL? in
            let idx = (currentIndex + offset) % ids.count
            return resolveURL(for: ids[idx])
        }
        decodeCache.preload(urls: lookahead)
    }
}

// Simple NSViewRepresentable to draw a CGImage with SwiftUI sizing
private struct CGContextImageView: NSViewRepresentable {
    let cgImage: CGImage

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleAxesIndependently
        return v
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(cgImage: cgImage, size: .zero)
    }
}


