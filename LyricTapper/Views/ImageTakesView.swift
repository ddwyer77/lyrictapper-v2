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
            List(selection: Binding(get: { app.projectV2.tracks.image.currentTakeId }, set: { app.setCurrentImageTake($0) })) {
                ForEach(app.projectV2.tracks.image.takes) { take in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(take.name)
                            Text("Images: \(take.imageCatalog.count) • Taps: \(take.tapTimestamps.count)")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Duplicate") { app.duplicateImageTake(take.id) }
                        Button("Delete") { app.deleteImageTake(take.id) }
                    }
                    .tag(Optional(take.id))
                }
            }
        }
        .padding(24)
    }
}


