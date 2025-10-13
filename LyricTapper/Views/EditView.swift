import SwiftUI

struct EditView: View {
    @ObservedObject var app: AppState
    @State private var nudgeMs: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Stepper("Nudge (ms): \(nudgeMs)", value: $nudgeMs, in: -5000...5000, step: 10)
                Button("Apply Nudge") { app.applyOffset(ms: nudgeMs) }
                Spacer()
                Button("Continue to Export") { app.stage = .export }
            }

            Table(app.project.timings) {
                TableColumn("#") { item in
                    Text(String(app.project.timings.firstIndex(where: { $0.id == item.id }) ?? 0 + 1))
                }
                TableColumn("Word") { item in Text(item.word) }
                TableColumn("Start") { item in Text(String(format: "%.3f", item.start)) }
                TableColumn("End") { item in Text(String(format: "%.3f", item.end)) }
            }
            .frame(minHeight: 240)
        }
        .padding()
    }
}


