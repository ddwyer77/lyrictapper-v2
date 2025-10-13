import Foundation
import AVFoundation
import Accelerate

struct WaveformBin: Codable, Equatable, Identifiable {
    let id: Int
    let rms: Float
}

enum WaveformService {
    static func computeRMSBins(url: URL, targetBins: Int = 1000) throws -> [WaveformBin] {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []

        while reader.status == .reading {
            if let sampleBuffer = output.copyNextSampleBuffer(),
               let block = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(block)
                var data = Data(count: length)
                data.withUnsafeMutableBytes { ptr in
                    if let p = ptr.baseAddress {
                        _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: p)
                    }
                }
                let floatCount = length / MemoryLayout<Float>.size
                data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    if let base = ptr.baseAddress?.assumingMemoryBound(to: Float.self) {
                        let buffer = UnsafeBufferPointer(start: base, count: floatCount)
                        samples.append(contentsOf: buffer)
                    }
                }
                CMSampleBufferInvalidate(sampleBuffer)
            } else {
                break
            }
        }

        guard samples.count > 0 else { return [] }

        let binSize = max(1, samples.count / max(1, targetBins))
        var bins: [WaveformBin] = []
        bins.reserveCapacity(max(1, samples.count / binSize))

        var index = 0
        var binIndex = 0
        while index < samples.count {
            let end = min(index + binSize, samples.count)
            let slice = Array(samples[index..<end])
            var meanSquare: Float = 0
            vDSP_measqv(slice, 1, &meanSquare, vDSP_Length(slice.count))
            let rms = sqrtf(max(0, meanSquare))
            bins.append(WaveformBin(id: binIndex, rms: rms.isFinite ? rms : 0))
            index = end
            binIndex += 1
        }

        if let maxVal = bins.map({ $0.rms }).max(), maxVal > 0 {
            return bins.map { WaveformBin(id: $0.id, rms: $0.rms / maxVal) }
        }
        return bins
    }
}


