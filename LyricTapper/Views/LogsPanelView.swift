import SwiftUI
import AppKit

struct LogsPanelView: View {
    @ObservedObject var logger: Logger

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diagnostics Log")
                    .font(.headline)
                Spacer()
                Button("Clear") { logger.clear() }
            }
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(logger.entries) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(ts(entry.timestamp)).foregroundColor(.secondary).font(.caption)
                                Text(tag(entry.level)).font(.caption2).padding(3).background(levelColor(entry.level).opacity(0.15)).cornerRadius(4)
                                Text(entry.message).font(.caption)
                                if let ctx = entry.context, !ctx.isEmpty { Text("- " + ctx).font(.caption).foregroundColor(.secondary) }
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(6)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: logger.entries.count) { _ in
                    if let last = logger.entries.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .padding(8)
        .frame(minHeight: 140)
        .border(Color.gray.opacity(0.2))
    }

    private func ts(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: d)
    }

    private func tag(_ l: LogEntry.Level) -> String {
        switch l { case .info: return "INFO"; case .warn: return "WARN"; case .error: return "ERROR" }
    }

    private func levelColor(_ l: LogEntry.Level) -> Color {
        switch l { case .info: return .blue; case .warn: return .orange; case .error: return .red }
    }

    // no-op: clear handled via logger.clear()
}


