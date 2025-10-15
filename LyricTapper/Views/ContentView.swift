import SwiftUI

struct ContentView: View {
    @ObservedObject var app: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(app: app)
                .frame(minWidth: 220)
        } detail: {
            switch app.stage {
            case .home:
                ProjectsLandingView(app: app)
            case .dashboard:
                DashboardView(app: app)
            case .loadAudio:
                LoadAudioView(app: app)
            case .enterLyrics:
                LoadLyricsView(app: app)
            case .tap:
                VStack(spacing: 8) {
                    TapView(app: app)
                    if app.showLogs {
                        LogsPanelView(logger: app.logger)
                    }
                }
            case .edit:
                VStack(spacing: 8) {
                    EditView(app: app)
                    if app.showLogs {
                        LogsPanelView(logger: app.logger)
                    }
                }
            case .export:
                VStack(spacing: 8) {
                    ExportView(app: app)
                    if app.showLogs {
                        LogsPanelView(logger: app.logger)
                    }
                }
            case .loadImages:
                LoadImagesView(app: app)
            case .imageTap:
                VStack(spacing: 8) {
                    ImageFlashTapView(app: app)
                    if app.showLogs { LogsPanelView(logger: app.logger) }
                }
            case .imageEdit:
                VStack(spacing: 8) {
                    ImageFlashEditView(app: app)
                    if app.showLogs { LogsPanelView(logger: app.logger) }
                }
            case .imageExport:
                VStack(spacing: 8) {
                    ImageFlashExportView(app: app)
                    if app.showLogs { LogsPanelView(logger: app.logger) }
                }
            case .mergeExport:
                VStack(spacing: 8) {
                    MergeExportView(app: app)
                    if app.showLogs { LogsPanelView(logger: app.logger) }
                }
            }
        }
        .toolbar { ToolbarItem(placement: .automatic) { Toggle(isOn: $app.showLogs) { Text("Logs") } } }
    }
}


