import Foundation
import AVFoundation
import CoreGraphics
import AppKit
import CoreText

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

                // Font selection for overlay (Core Text for thread-safe draw)
                let relSize: CGFloat = CGFloat(lyricTake?.fontSize ?? 0.18)
                let fontSize = max(12.0, relSize * CGFloat(min(settings.width, settings.height)))
                let ctFont: CTFont = {
                    let family = lyricTake?.fontFamily ?? "Helvetica Neue"
                    return CTFontCreateWithName(family as CFString, fontSize, nil)
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
                            if let take = lyricTake, !take.timings.isEmpty {
                                let tLyric = tSec + Double(lyricOffsetMs) / 1000.0
                                // Find last timing <= tLyric to ensure coverage at boundaries
                                let w = take.timings.last(where: { $0.start <= tLyric && tLyric < $0.end })
                                if let w = w {
                                    let text = w.word
                                    let white = CGColor(gray: 1.0, alpha: 1.0)
                                    let black = CGColor(gray: 0.0, alpha: 1.0)
                                    let attrs: [NSAttributedString.Key: Any] = [
                                        NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
                                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): white,
                                        NSAttributedString.Key(kCTStrokeColorAttributeName as String): black,
                                        NSAttributedString.Key(kCTStrokeWidthAttributeName as String): -2.0
                                    ]
                                    let attr = NSAttributedString(string: text, attributes: attrs)
                                    let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
                                    var ascent: CGFloat = 0
                                    var descent: CGFloat = 0
                                    var leading: CGFloat = 0
                                    let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
                                    let x = (CGFloat(settings.width) - lineWidth) / 2.0
                                    // Draw in current (top-left origin) coordinate system
                                    let lineHeight = ascent + descent
                                    let baselineY = ((CGFloat(settings.height) - lineHeight) / 2.0) + ascent
                                    ctx?.textPosition = CGPoint(x: x, y: baselineY)
                                    CTLineDraw(line, ctx!)
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

// Local helpers (duplicated from ExportService but file-private there)
private func audioDuration(_ url: URL) throws -> Double {
    let asset = AVAsset(url: url)
    let seconds = CMTimeGetSeconds(asset.duration)
    guard seconds.isFinite && seconds > 0 else { throw ExportServiceError.missingAudio }
    return seconds
}

private func muxAudioVideo(audioURL: URL, videoURL: URL, destinationURL: URL) throws {
    let composition = AVMutableComposition()
    let audioAsset = AVAsset(url: audioURL)
    let videoAsset = AVAsset(url: videoURL)

    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else { throw ExportServiceError.compositionFailed }
    let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)

    if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
        let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try compAudio.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: audioTrack, at: .zero)
    }

    if FileManager.default.fileExists(atPath: destinationURL.path) { try? FileManager.default.removeItem(at: destinationURL) }
    guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw ExportServiceError.compositionFailed }
    export.outputURL = destinationURL
    export.outputFileType = .mp4
    export.shouldOptimizeForNetworkUse = true
    let g = DispatchGroup(); var exportErr: Error?; g.enter()
    export.exportAsynchronously { if export.status != .completed { exportErr = export.error ?? ExportServiceError.compositionFailed }; g.leave() }
    g.wait()
    if let e = exportErr { throw e }
}


