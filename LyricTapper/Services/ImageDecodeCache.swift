import Foundation
import ImageIO
import AppKit

final class ImageDecodeCache {
    private let targetWidth: Int
    private let cache = NSCache<NSData, CGImageWrapper>()
    private let queue = DispatchQueue(label: "image.decode.cache", qos: .userInitiated)

    init(targetWidth: Int = 1080) {
        self.targetWidth = targetWidth
        cache.countLimit = 128
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func decodedScaledToWidth(url: URL) -> CGImage? {
        let key = (url.absoluteString as NSString).data(using: String.Encoding.utf8.rawValue)! as NSData
        if let wrapped = cache.object(forKey: key) { return wrapped.image }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let maxSize = targetWidth
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceShouldCache: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        cache.setObject(CGImageWrapper(image: cg), forKey: key, cost: cg.height * cg.bytesPerRow)
        return cg
    }

    func preload(urls: [URL]) {
        queue.async { [weak self] in
            guard let self else { return }
            for url in urls.prefix(8) { _ = self.decodedScaledToWidth(url: url) }
        }
    }
}

private final class CGImageWrapper: NSObject {
    let image: CGImage
    init(image: CGImage) { self.image = image }
}


