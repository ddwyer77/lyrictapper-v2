import Foundation
import AVFoundation

@MainActor
final class AudioService: ObservableObject {
    private var player: AVAudioPlayerNode = AVAudioPlayerNode()
    private let engine: AVAudioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?

    @Published var isPlaying: Bool = false
    @Published var duration: Double = 0

    private var startTimeReference: AVAudioTime?
    private var pendingStartSeconds: Double = 0

    init() {
        engine.attach(player)
        let mainMixer = engine.mainMixerNode
        engine.connect(player, to: mainMixer, format: nil)
    }

    func loadFile(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        self.audioFile = file
        duration = file.durationSeconds
    }

    func prepareEngineIfNeeded() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    func play(from seconds: Double? = nil) throws {
        guard let audioFile else { return }
        try prepareEngineIfNeeded()

        let sampleRate = audioFile.processingFormat.sampleRate
        let frameCount = AVAudioFrameCount(audioFile.length)
        let startFrame: AVAudioFramePosition
        if let seconds {
            startFrame = AVAudioFramePosition(seconds * sampleRate)
        } else {
            startFrame = AVAudioFramePosition(pendingStartSeconds * sampleRate)
        }
        let framesToPlay = frameCount - AVAudioFrameCount(max(0, startFrame))

        if !engine.isRunning {
            try engine.start()
        }
        player.stop()
        player.scheduleSegment(audioFile, startingFrame: startFrame, frameCount: framesToPlay, at: nil)
        player.play()
        isPlaying = true
        startTimeReference = engine.outputNode.lastRenderTime
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func stop() {
        player.stop()
        isPlaying = false
    }

    func toggle() throws {
        if isPlaying {
            pause()
        } else {
            try play()
        }
    }

    func restart() throws {
        stop()
        try play(from: 0)
    }

    func resetToStart() {
        // Stop playback and leave engine running; next play() will start from 0
        stop()
        pendingStartSeconds = 0
    }

    func seek(to seconds: Double) {
        // Pause and set pending start; next play will start here
        pause()
        pendingStartSeconds = max(0, min(seconds, duration))
    }

    func currentTimeSeconds() -> Double {
        guard isPlaying, let nodeTime = player.lastRenderTime, let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return pendingStartSeconds
        }
        let seconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        return max(0, min(pendingStartSeconds + seconds, duration))
    }
}

private extension AVAudioFile {
    var durationSeconds: Double {
        let frames = Double(length)
        let rate = processingFormat.sampleRate
        return frames / rate
    }
}


