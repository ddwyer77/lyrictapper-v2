import SwiftUI

struct SidebarView: View {
    @ObservedObject var app: AppState

    var body: some View {
        List(selection: $app.stage) {
            Section {
                Label("Lyric Tapper", systemImage: "music.note")
                    .font(.headline)
                EmptyView()
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Section("Steps") {
                Label("Load Audio", systemImage: "folder")
                    .tag(AppState.Stage.loadAudio)
                Label("Enter Lyrics", systemImage: "text.justify")
                    .tag(AppState.Stage.enterLyrics)
                Label("Tap", systemImage: "hand.tap")
                    .tag(AppState.Stage.tap)
                Label("Edit", systemImage: "table")
                    .tag(AppState.Stage.edit)
                Label("Export", systemImage: "square.and.arrow.up")
                    .tag(AppState.Stage.export)
            }
        }
        .listStyle(SidebarListStyle())
    }
}


