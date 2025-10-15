import SwiftUI

struct WaveformTrimView: View {
    let bins: [WaveformBin]
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double

    private let minLen: Double = 0.1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Waveform bars
                Canvas { context, size in
                    let w = max(1, size.width)
                    let h = max(1, size.height)
                    let count = max(1, bins.count)
                    let step = w / CGFloat(count)
                    let midY = h / 2
                    guard count > 1 else { return }
                    for (idx, bin) in bins.enumerated() {
                        let x = CGFloat(idx) * step
                        let magnitude = CGFloat(max(0, min(1, bin.rms)))
                        let barHeight = max(1, magnitude * (h * 0.9))
                        let rect = CGRect(x: x, y: midY - barHeight / 2, width: max(1, step * 0.9), height: barHeight)
                        context.fill(Path(rect), with: .color(.accentColor))
                    }
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)

                // Selection overlay
                selectionOverlay(width: geo.size.width)
            }
        }
        .frame(height: 140)
    }

    private func selectionOverlay(width: CGFloat) -> some View {
        let xStart = CGFloat(start / max(duration, 0.0001)) * width
        let xEnd = CGFloat(end / max(duration, 0.0001)) * width
        let selRect = CGRect(x: min(xStart, xEnd), y: 0, width: abs(xEnd - xStart), height: 140)

        return ZStack(alignment: .leading) {
            // Dim outside selection
            HStack(spacing: 0) {
                Color.black.opacity(0.25).frame(width: max(0, selRect.minX))
                Color.clear.frame(width: max(0, selRect.width))
                Color.black.opacity(0.25).frame(maxWidth: .infinity)
            }

            // Selection border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: max(2, selRect.width), height: selRect.height)
                .position(x: selRect.midX, y: selRect.midY)

            // Left handle
            handleView()
                .position(x: selRect.minX, y: selRect.midY)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let newX = max(0, min(width, value.location.x))
                    let newStart = Double(newX / width) * duration
                    start = min(newStart, end - minLen)
                })

            // Right handle
            handleView()
                .position(x: selRect.maxX, y: selRect.midY)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let newX = max(0, min(width, value.location.x))
                    let newEnd = Double(newX / width) * duration
                    end = max(newEnd, start + minLen)
                })
        }
    }

    private func handleView() -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 6, height: 140)
            .shadow(radius: 1)
            .contentShape(Rectangle())
    }
}


