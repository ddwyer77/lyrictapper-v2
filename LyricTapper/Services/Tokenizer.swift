import Foundation
import CoreText
import CoreFoundation

enum Tokenizer {
    static func tokenize(lyricsRaw: String) -> [WordToken] {
        let separators = CharacterSet.whitespacesAndNewlines
        let rough = lyricsRaw
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        var index = 0
        let locale = Locale(identifier: "en_US") as CFLocale
        let tokens: [WordToken] = rough.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: CharacterSet.punctuationCharacters)
            guard !trimmed.isEmpty else { return nil }
            let breaks = hyphenBreaks(for: trimmed, locale: locale)
            let count = max(1, breaks.count + 1)
            defer { index += 1 }
            return WordToken(id: UUID().uuidString, text: trimmed, index: index, syllableCount: count, hyphenBreaks: breaks)
        }

        return tokens
    }

    private static func hyphenBreaks(for word: String, locale: CFLocale) -> [Int] {
        let ns = word as NSString
        let length = ns.length
        guard length > 1 else { return [] }
        let cfLocale = CFStringIsHyphenationAvailableForLocale(locale) ? locale : CFLocaleCopyCurrent()
        guard CFStringIsHyphenationAvailableForLocale(cfLocale) else { return [] }
        let range = CFRange(location: 0, length: length)
        var out: Set<Int> = []
        var idx: CFIndex = 1
        var safety = 0
        while idx < length && safety < length {
            let loc = CFStringGetHyphenationLocationBeforeIndex(word as CFString, idx, range, 0, cfLocale, nil)
            if loc != kCFNotFound && loc > 0 && loc < length {
                out.insert(loc)
                idx = loc + 1
            } else {
                idx += 1
            }
            safety += 1
        }
        return out.sorted()
    }
}


