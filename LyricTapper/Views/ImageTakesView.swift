import SwiftUI

struct ImageTakesView: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Takes").font(.title2)
            HStack(spacing: 8) {
                Button("New Take") { app.stage = .imageTap }
                Spacer()
            }
            Text("Use New Take to capture taps; takes management UI will appear here.")
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
}


