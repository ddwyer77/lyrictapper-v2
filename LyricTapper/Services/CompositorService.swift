import Foundation
import AVFoundation
import CoreGraphics
import AppKit

enum CompositorService {
    // Final export: render images (hard cuts) and overlay lyric text (rerender)
    static func exportFinal(
        audioURL: URL,
        imageIntervals: [ImageInterval],
        settings: RenderSettings,
        lyricTake: TrackLyricTake? = nil,
        lyricOffsetMs: Int = 0,
        imageOffsetMs: Int = 0,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let duration = try audioDuration(audioURL)
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("final_merged_\(UUID().uuidString).mp4")
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: settings.width,
                    AVVideoHeightKey: settings.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 14_000_000,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = false
                guard writer.canAdd(videoInput) else { throw ExportServiceError.writerFailed }
                writer.add(videoInput)
                let srcAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: settings.width,
                    kCVPixelBufferHeightKey as String: settings.height,
                    kCVPixelBufferCGImageCompatibilityKey as String: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: srcAttrs)
                writer.startWriting(); writer.startSession(atSourceTime: .zero)
                guard let pool = adaptor.pixelBufferPool else { throw ExportServiceError.writerFailed }

                // Pre-resolve image URLs
                var fileIdToURL: [ImageFileID: URL] = [:]
                for iv in imageIntervals { if fileIdToURL[iv.fileID] == nil, let url = BookmarkService.resolveBookmark(iv.fileID.urlBookmark) { fileIdToURL[iv.fileID] = url } }
                let decodeCache = ImageDecodeCache(targetWidth: settings.width)

                // Pacing
                let fps = max(1, settings.fps)
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                let totalFrames = Int(ceil(duration * Double(fps)))
                var frameTime = CMTime.zero
                var frameIndex = 0

                // Font selection for overlay
                let fontSize = CGFloat(0.18) * CGFloat(min(settings.width, settings.height))
                let nsFont: NSFont = {
                    if let take = lyricTake {
                        if let path = take.fontFilePath, let provider = CGDataProvider(url: URL(fileURLWithPath: path) as CFURL), let cgFont = CGFont(provider), let f = NSFont(name: cgFont.postScriptName as String? ?? "", size: fontSize) { return f }
                        if let family = take.fontFamily, let f = NSFont(name: family, size: fontSize) { return f }
                    }
                    return NSFont.systemFont(ofSize: fontSize)
                }()

                while frameIndex < totalFrames {
                    autoreleasepool {
                        while !videoInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
                        var pbOut: CVPixelBuffer? = nil
                        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
                        guard let pb = pbOut else { return }
                        CVPixelBufferLockBaseAddress(pb, [])
                        if let base = CVPixelBufferGetBaseAddress(pb) {
                            let ctx = CGContext(
                                data: base,
                                width: settings.width,
                                height: settings.height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                            )
                            // Black background
                            ctx?.setFillColor(NSColor.black.cgColor)
                            ctx?.fill(CGRect(x: 0, y: 0, width: settings.width, height: settings.height))

                            // Draw image
                            let tSec = Double(frameIndex) / Double(fps)
                            let tAdj = tSec + Double(imageOffsetMs) / 1000.0
                            if let iv = imageIntervals.first(where: { tAdj >= $0.start && tAdj < $0.end }), let url = fileIdToURL[iv.fileID], let cg = decodeCache.decodedScaledToWidth(url: url) {
                                let scale = CGFloat(settings.width) / CGFloat(cg.width)
                                let destH = Int(CGFloat(cg.height) * scale)
                                let y = (settings.height - destH) / 2
                                ctx?.interpolationQuality = .high
                                ctx?.draw(cg, in: CGRect(x: 0, y: y, width: settings.width, height: destH))
                            }

                            // Overlay lyric text
                            if let take = lyricTake {
                                let tLyric = tSec + Double(lyricOffsetMs) / 1000.0
                                if let w = take.timings.first(where: { tLyric >= $0.start && tLyric < $0.end }) {
                                    let text = w.word
                                    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                                    let attrs: [NSAttributedString.Key: Any] = [ .font: nsFont, .foregroundColor: NSColor.white, .paragraphStyle: paragraph ]
                                    let attr = NSAttributedString(string: text, attributes: attrs)
                                    let boxHeight = nsFont.pointSize * 1.2
                                    let box = CGRect(x: 0, y: (CGFloat(settings.height) - boxHeight) / 2.0, width: CGFloat(settings.width), height: boxHeight)
                                    attr.draw(in: box)
                                }
                            }
                        }
                        CVPixelBufferUnlockBaseAddress(pb, [])
                        let ok = adaptor.append(pb, withPresentationTime: frameTime)
                        if !ok { videoInput.markAsFinished(); writer.cancelWriting(); return }
                    }
                    frameIndex += 1
                    frameTime = CMTimeAdd(frameTime, frameDuration)
                }

                videoInput.markAsFinished()
                let g = DispatchGroup(); g.enter(); writer.finishWriting { g.leave() }; g.wait()
                if writer.status != .completed { throw writer.error ?? ExportServiceError.writerFailed }

                let finalURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("final_muxed_\(UUID().uuidString).mp4")
                try muxAudioVideo(audioURL: audioURL, videoURL: outputURL, destinationURL: finalURL)
                completion(.success(finalURL))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// Internal helper bridging to existing private functions
private func ExportService_renderImageTimeline(to url: URL, audioURL: URL, intervals: [ImageInterval], settings: ExportSettings) throws {
    // Call the image flash writer used by ExportService
    try renderImageFlashVideoOnly(to: url, audioURL: audioURL, intervals: intervals, width: settings.width, height: settings.height, fps: settings.fps)
}


