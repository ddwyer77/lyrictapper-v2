import SwiftUI

struct SidebarView: View {
    @ObservedObject var app: AppState

    var body: some View {
        List(selection: $app.stage) {
            Section {
                Button { app.stage = .home } label: { Label("Home", systemImage: "house") }
                    .buttonStyle(.plain)
                Button { app.stage = .dashboard } label: { Label("Dashboard", systemImage: "rectangle.grid.2x2") }
                    .buttonStyle(.plain)
            }
            if app.activeTool == .lyrics {
                Section("Lyric Tool") {
                    Label("Takes", systemImage: "square.stack").tag(AppState.Stage.lyricTakes)
                    Label("Load Audio", systemImage: "folder").tag(AppState.Stage.loadAudio)
                    Label("Enter Lyrics", systemImage: "text.justify").tag(AppState.Stage.enterLyrics)
                    Label("Tap", systemImage: "hand.tap").tag(AppState.Stage.tap)
                    Label("Edit", systemImage: "table").tag(AppState.Stage.edit)
                    Label("Export", systemImage: "square.and.arrow.up").tag(AppState.Stage.export)
                }
            } else {
                Section("Image Flash") {
                    Label("Takes", systemImage: "square.stack").tag(AppState.Stage.imageTakes)
                    Label("Load Images", systemImage: "folder").tag(AppState.Stage.loadImages)
                    Label("Tap", systemImage: "hand.tap").tag(AppState.Stage.imageTap)
                    Label("Edit", systemImage: "table").tag(AppState.Stage.imageEdit)
                    Label("Export", systemImage: "square.and.arrow.up").tag(AppState.Stage.imageExport)
                }
            }
            Section("Merge") {
                Label("Merge & Export", systemImage: "square.stack.3d.up").tag(AppState.Stage.mergeExport)
            }
        }
        .listStyle(SidebarListStyle())
    }
}


