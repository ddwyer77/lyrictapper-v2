import SwiftUI

struct DashboardView: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Dashboard")
                .font(.title2)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio")
                        .font(.headline)
                    if app.project.audioDuration > 0 {
                        Text(String(format: "Duration: %.2f s", app.project.audioDuration))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No audio selected").foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lyric Track")
                        .font(.headline)
                    Button("Open Lyric Tools") { app.switchTool(.lyrics) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Track")
                        .font(.headline)
                    Button("Open Image Flash") { app.switchTool(.imageFlash) }
                }
                Spacer()
            }
            Spacer()
        }
        .padding(24)
    }
}


