import Foundation
import AppKit
import UniformTypeIdentifiers
import ImageIO

enum ImageSequenceService {
    static func buildCatalog(folderBookmark: Data, includeSubfolders: Bool, skipDuplicates: Bool, logger: Logger) -> (catalog: [ImageFileID: ImageMeta], ordered: [ImageFileID]) {
        var outCatalog: [ImageFileID: ImageMeta] = [:]
        var ordered: [ImageFileID] = []
        guard let root = BookmarkService.resolveBookmark(folderBookmark), root.startAccessingSecurityScopedResource() else {
            logger.log(.error, "Folder access failed")
            return (outCatalog, ordered)
        }
        defer { root.stopAccessingSecurityScopedResource() }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .nameKey, .typeIdentifierKey]
        let enumOpts: FileManager.DirectoryEnumerationOptions = includeSubfolders ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: enumOpts) else { return (outCatalog, ordered) }

        var seenHashes: Set<String> = []
        var acceptedCount = 0
        for case let url as URL in en {
            do {
                let rv = try url.resourceValues(forKeys: Set(keys))
                guard rv.isRegularFile == true else { continue }
                let uti = rv.typeIdentifier ?? "public.data"
                guard ImageSequenceService.isDecodableImageUTI(uti) else { continue }
                let bookmark = try BookmarkService.createBookmark(for: url)
                let id = ImageFileID(urlBookmark: bookmark)
                let (w, h) = ImageSequenceService.readDimensions(url: url)
                let fname = rv.name ?? url.lastPathComponent
                let fsize = rv.fileSize != nil ? Int64(rv.fileSize!) : nil
                var fastHash: String? = nil
                if skipDuplicates {
                    fastHash = ImageSequenceService.fastHash(url: url)
                    if let hh = fastHash, seenHashes.contains(hh) { continue }
                    if let hh = fastHash { seenHashes.insert(hh) }
                }
                let meta = ImageMeta(originalFilename: fname, pixelWidth: w, pixelHeight: h, uti: uti, fileSize: fsize, fastHash: fastHash)
                outCatalog[id] = meta
                ordered.append(id)
                acceptedCount += 1
            } catch {
                logger.log(.warn, "Skip file", context: url.lastPathComponent)
            }
        }
        logger.log(.info, "Images discovered", context: "count=\(acceptedCount)")
        return (outCatalog, ordered)
    }

    static func isDecodableImageUTI(_ uti: String) -> Bool {
        guard let t = UTType(uti) else { return false }
        return t.conforms(to: .image)
    }

    static func readDimensions(url: URL) -> (Int, Int) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return (0, 0) }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return (0, 0) }
        let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        return (w, h)
    }

    static func fastHash(url: URL, bytes: Int = 131072) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        let data = try? fh.read(upToCount: bytes)
        guard let data else { return nil }
        // Simple, fast non-cryptographic hash
        var h: UInt64 = 1469598103934665603
        for b in data { h ^= UInt64(b); h &*= 1099511628211 }
        return String(format: "%016llx", h)
    }

    static func shuffleBagOrder<T: Equatable>(items: [T], seed: UInt64) -> [T] {
        guard !items.isEmpty else { return [] }
        var rngSeed = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        var bag = items
        seededShuffle(&bag, seed: rngSeed)
        var order: [T] = bag
        while order.count < max(items.count, 10_000 / max(1, items.count)) * items.count {
            rngSeed &+= 0x9E3779B97F4A7C15
            var nextBag = items
            seededShuffle(&nextBag, seed: rngSeed)
            if let last = order.last, let first = nextBag.first, last == first, nextBag.count > 1 {
                nextBag.swapAt(0, 1)
            }
            order.append(contentsOf: nextBag)
        }
        return order
    }

    static func reshuffle(project: inout Project, seed: UInt64) {
        project.shuffleSeed = seed
        let keys = Array(project.imageCatalog.keys)
        let order = shuffleBagOrder(items: keys, seed: seed)
        project.imageFileIDs = order
    }
}

private struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        var x = state
        x ^= x >> 12; x ^= x << 25; x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }
    mutating func nextInt(_ n: Int) -> Int { Int(next() % UInt64(n)) }
}

private func seededShuffle<T>(_ array: inout [T], seed: UInt64) {
    var rng = SeededRandom(seed)
    if array.count <= 1 { return }
    for i in stride(from: array.count - 1, through: 1, by: -1) {
        let j = rng.nextInt(i + 1)
        if i != j { array.swapAt(i, j) }
    }
}


