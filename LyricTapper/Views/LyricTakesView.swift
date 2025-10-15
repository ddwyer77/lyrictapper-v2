import SwiftUI

struct LyricTakesView: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lyric Takes").font(.title2)
            HStack(spacing: 8) {
                Button("New Take") { app.stage = .tap }
                Spacer()
            }
            List(selection: Binding(get: { app.projectV2.tracks.lyric.currentTakeId }, set: { app.setCurrentLyricTake($0) })) {
                ForEach(app.projectV2.tracks.lyric.takes) { take in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(take.name)
                            Text("Taps: \(take.tapTimestamps.count)")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Duplicate") { app.duplicateLyricTake(take.id) }
                        Button("Delete") { app.deleteLyricTake(take.id) }
                    }
                    .tag(Optional(take.id))
                }
            }
        }
        .padding(24)
    }
}


