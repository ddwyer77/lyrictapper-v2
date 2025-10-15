import SwiftUI

struct LoadLyricsView: View {
    @ObservedObject var app: AppState
    @State private var lyricsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter Lyrics")
                .font(.title2)
            TextEditor(text: $lyricsText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 240)
                .border(Color.gray.opacity(0.25))
                .onChange(of: lyricsText) { newValue in
                    app.updateLyrics(newValue)
                }

            HStack {
                Text("Tokens: \(Tokenizer.tokenize(lyricsRaw: lyricsText).count)")
                Spacer()
                Button("Continue") { app.stage = .tap }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear {
            if let v2 = app.projectV2.lyricsRaw, !v2.isEmpty {
                lyricsText = v2
                app.project.lyricsRaw = v2
                app.project.tokens = Tokenizer.tokenize(lyricsRaw: v2)
            } else {
                lyricsText = app.project.lyricsRaw
            }
        }
    }
}


