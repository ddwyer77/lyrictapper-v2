import Foundation

enum TimingService {
    static func computeTimings(
        taps: [Tap],
        tokens: [WordToken],
        audioDuration: Double,
        offsetMs: Int
    ) -> [WordTiming] {
        // Default word-per-tap mapping
        guard !tokens.isEmpty, audioDuration > 0 else { return [] }
        let n = min(taps.count, tokens.count)
        guard n > 0 else { return [] }

        let o = Double(offsetMs) / 1000.0
        let D = max(0.0, audioDuration)

        var timings: [WordTiming] = []
        timings.reserveCapacity(n)

        var lastEnd = 0.0
        for i in 0..<n {
            let startRaw = (taps[i].t + o).clamped(to: 0...D)
            let endRaw: Double
            if i < n - 1 {
                endRaw = (taps[i + 1].t + o).clamped(to: 0...D)
            } else {
                endRaw = D
            }

            let start = max(startRaw, lastEnd)
            let end = max(endRaw, start)
            let token = tokens[i]
            timings.append(WordTiming(id: token.id, word: token.text, start: start, end: end))
            lastEnd = end
        }

        return timings
    }

    static func computeTimingsPerSyllable(
        taps: [Tap],
        tokens: [WordToken],
        audioDuration: Double,
        offsetMs: Int
    ) -> [WordTiming] {
        guard !tokens.isEmpty, audioDuration > 0 else { return [] }
        if taps.isEmpty { return [] }
        let o = Double(offsetMs) / 1000.0
        let D = max(0.0, audioDuration)

        var i = 0 // taps index
        var out: [WordTiming] = []
        out.reserveCapacity(tokens.count)
        var lastEnd = 0.0

        for token in tokens {
            let need = max(1, token.syllableCount)
            guard i < taps.count else { break }
            let take = min(need, taps.count - i)
            let slice = Array(taps[i..<(i + take)])
            i += take

            let s0 = slice.first?.t ?? lastEnd
            // Prefer the time of the next global tap as the word end if available; if none (last word), hold until end of audio
            let nextGlobalTapT: Double? = (i < taps.count) ? taps[i].t : nil
            let startRaw = (s0 + o).clamped(to: 0...D)
            var endRaw: Double
            if let nextT = nextGlobalTapT {
                endRaw = (nextT + o).clamped(to: 0...D)
            } else {
                endRaw = D
            }
            // Ensure a minimal non-zero duration if rounding causes equality
            if endRaw <= startRaw { endRaw = min(D, startRaw + 0.08) }
            let start = max(startRaw, lastEnd)
            let end = max(endRaw, start)
            out.append(WordTiming(id: token.id, word: token.text, start: start, end: end))
            lastEnd = end
        }
        return out
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}


