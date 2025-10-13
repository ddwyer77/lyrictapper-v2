import SwiftUI

struct WaveformScrubView: View {
    @ObservedObject var app: AppState
    @ObservedObject var audio: AudioService

    @State private var isScrubbing: Bool = false
    @State private var scrubProgress: Double = 0 // 0..1 while scrubbing

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                WaveformView(bins: app.waveform, color: .blue.opacity(0.8))
                // Playhead
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: geo.size.height)
                    .offset(x: CGFloat(currentProgress()) * geo.size.width)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = max(0, min(value.location.x, geo.size.width))
                    let p = Double(x / geo.size.width)
                    if !isScrubbing { isScrubbing = true; audio.pause() }
                    scrubProgress = p
                }
                .onEnded { value in
                    let x = max(0, min(value.location.x, geo.size.width))
                    let p = Double(x / geo.size.width)
                    let t = p * max(0.0, audio.duration)
                    audio.seek(to: t)
                    isScrubbing = false
                }
            )
        }
    }

    private func currentProgress() -> CGFloat {
        if isScrubbing { return CGFloat(scrubProgress) }
        let p = audio.duration > 0 ? audio.currentTimeSeconds() / max(0.0001, audio.duration) : 0
        return CGFloat(max(0, min(1, p)))
    }
}


