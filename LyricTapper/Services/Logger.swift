import Foundation

struct LogEntry: Identifiable, Codable, Equatable {
    enum Level: String, Codable { case info, warn, error }
    let id: String
    let timestamp: Date
    let level: Level
    let message: String
    let context: String?
}

@MainActor
final class Logger: ObservableObject {
    static let shared = Logger()
    @Published private(set) var entries: [LogEntry] = []

    private init() {}

    func log(_ level: LogEntry.Level, _ message: String, context: String? = nil) {
        let entry = LogEntry(id: UUID().uuidString, timestamp: Date(), level: level, message: message, context: context)
        entries.append(entry)
        if entries.count > 2000 { entries.removeFirst(entries.count - 2000) }
        #if DEBUG
        print("[\(level.rawValue.uppercased())] \(message)\(context != nil ? " | " + (context ?? "") : "")")
        #endif
    }

    func clear() {
        entries.removeAll()
    }
}

extension Logger {
    // Thread-safe convenience for background contexts (avoids MainActor compile-time restrictions)
    nonisolated static func logAsync(_ level: LogEntry.Level, _ message: String, context: String? = nil) {
        DispatchQueue.main.async {
            Logger.shared.log(level, message, context: context)
        }
    }
}


