import SwiftUI

@main
struct LyricTapperApp: App {
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(app: appState)
        }
    }
}


