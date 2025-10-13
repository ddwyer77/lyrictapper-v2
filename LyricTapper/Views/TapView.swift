import SwiftUI
import AppKit

struct TapView: View {
    @ObservedObject var app: AppState
    @StateObject var audio = AudioService()
    @State private var nextWordIndex: Int = 0
    @State private var loadStatus: String = ""

    var nextWord: String {
        let count = app.project.tokens.count
        guard nextWordIndex >= 0, nextWordIndex < count else { return "" }
        return app.project.tokens[nextWordIndex].text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KeyCaptureView {
                if audio.isPlaying {
                    let t = audio.currentTimeSeconds()
                    if app.project.tokens.isEmpty {
                        app.logger.log(.warn, "Tap ignored: no tokens available")
                    } else {
                        app.pushTap(atSeconds: t)
                        if app.project.tapMode == .perSyllable {
                            let tapsCount = app.project.taps.count
                            var used = 0
                            var idx = 0
                            while idx < app.project.tokens.count {
                                used += max(1, app.project.tokens[idx].syllableCount)
                                if tapsCount < used { // still within this word
                                    break
                                } else if tapsCount == used { // finished this word
                                    idx += 1
                                    break
                                } else {
                                    idx += 1 // move to next word and continue
                                }
                            }
                            let upper = max(0, app.project.tokens.count - 1)
                            nextWordIndex = min(max(0, idx), upper)
                        } else {
                            let next = app.project.taps.count
                            let upper = max(0, app.project.tokens.count - 1)
                            nextWordIndex = min(max(0, next), upper)
                        }
                    }
                } else {
                    do { try audio.toggle() } catch { }
                }
            }
            .background(Color.clear)
            HStack(spacing: 12) {
                Button(audio.isPlaying ? "Pause" : "Play") {
                    do { try audio.toggle() } catch { }
                }
                Button("Restart") {
                    audio.resetToStart()
                    app.clearTaps()
                    nextWordIndex = 0
                }
                Picker("Mode", selection: $app.project.tapMode) {
                    Text("Words").tag(TapMode.perWord)
                    Text("Syllables").tag(TapMode.perSyllable)
                }
                .pickerStyle(.segmented)
                Spacer()
                let displayIndex = max(0, min(nextWordIndex + 1, app.project.tokens.count))
                Text("Next: \(nextWord) (\(displayIndex)/\(app.project.tokens.count))")
                    .font(.headline)
            }

            if !app.waveform.isEmpty {
                WaveformScrubView(app: app, audio: audio)
                    .frame(height: 160)
                    .padding(.vertical, 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Press Space while the audio plays to record taps.")
                Text("Mode: Words → one tap per word. Syllables → multiple taps per multi-syllable words.")
                Text("Tip: Use the timeline to scrub. Restart clears taps and returns to 0.")
            }
            .font(.callout)
            .foregroundColor(.secondary)

            ScrollView {
                Text(app.project.lyricsRaw.isEmpty ? "Enter lyrics first in the previous step." : app.project.lyricsRaw)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 200)

            HStack {
                Spacer()
                Button("Continue to Edit") { app.stage = .edit }
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
                    loadStatus = "Loaded audio for tapping."
                } catch {
                    loadStatus = "Failed to load audio: \(error.localizedDescription)"
                }
            }
        }
    }
}


