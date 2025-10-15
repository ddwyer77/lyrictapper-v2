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
            Text("Use New Take to record taps; set as current from the list below once takes are implemented.")
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
}


