import Foundation

enum BookmarkService {
    static func createBookmark(for url: URL) throws -> Data {
        return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            return url
        } catch {
            return nil
        }
    }

    static func withScopedAccess<T>(bookmark: Data, _ body: (URL) throws -> T) rethrows -> T? {
        guard let url = resolveBookmark(bookmark) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? body(url)
    }
}


