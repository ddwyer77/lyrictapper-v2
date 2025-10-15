import Foundation
import CoreVideo
import CoreGraphics
import AVFoundation
import AppKit

enum OverlayRenderService {
    static func renderLyricOverlayPixelBuffer(at time: CMTime, take: TrackLyricTake, settings: RenderSettings) -> CVPixelBuffer {
        let attrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: settings.width,
            kCVPixelBufferHeightKey as String: settings.height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        var pb: CVPixelBuffer? = nil
        CVPixelBufferCreate(kCFAllocatorDefault, settings.width, settings.height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        guard let pixelBuffer = pb else { fatalError("CVPixelBufferCreate failed") }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let ctx = CGContext(
                data: base,
                width: settings.width,
                height: settings.height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
            // Transparent background (clear)
            ctx?.setBlendMode(.copy)
            ctx?.clear(CGRect(x: 0, y: 0, width: settings.width, height: settings.height))
            // TODO: Draw text overlay from 'take.timings' according to 'time'
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }

    static func exportLyricOverlayMovie(take: TrackLyricTake, settings: RenderSettings, destinationURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) { try? FileManager.default.removeItem(at: destinationURL) }
                let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
                let codec: AVVideoCodecType
                if #available(macOS 13.0, *) { codec = .hevcWithAlpha } else { codec = .proRes4444 }
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: codec,
                    AVVideoWidthKey: settings.width,
                    AVVideoHeightKey: settings.height
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                input.expectsMediaDataInRealTime = false
                guard writer.canAdd(input) else { throw ExportServiceError.writerFailed }
                writer.add(input)
                let attrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: settings.width,
                    kCVPixelBufferHeightKey as String: settings.height,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                let fps = max(1, settings.fps)
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                var t = CMTime.zero
                let totalFrames = fps * 1 // 1-second placeholder
                var frame = 0
                while frame < totalFrames {
                    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
                    let pb = renderLyricOverlayPixelBuffer(at: t, take: take, settings: settings)
                    _ = adaptor.append(pb, withPresentationTime: t)
                    t = CMTimeAdd(t, frameDuration)
                    frame += 1
                }
                input.markAsFinished()
                let g = DispatchGroup(); g.enter(); writer.finishWriting { g.leave() }; g.wait()
                if writer.status != .completed { throw writer.error ?? ExportServiceError.writerFailed }
                completion(.success(destinationURL))
            } catch {
                completion(.failure(error))
            }
        }
    }
}


