import SwiftUI

struct WaveformView: View {
    let bins: [WaveformBin]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let count = max(1, bins.count)
            let step = w / CGFloat(count)
            let midY = h / 2

            Canvas { context, size in
                guard count > 1 else { return }
                for (idx, bin) in bins.enumerated() {
                    let x = CGFloat(idx) * step
                    let magnitude = CGFloat(max(0, min(1, bin.rms)))
                    let barHeight = max(1, magnitude * (h * 0.9))
                    let rect = CGRect(x: x, y: midY - barHeight / 2, width: max(1, step * 0.9), height: barHeight)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}


