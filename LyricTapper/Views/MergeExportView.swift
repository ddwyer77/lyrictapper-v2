import SwiftUI

struct MergeExportView: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Merge & Export Final").font(.title2)
            Text("This is a placeholder UI. The compositor/export pipeline will be added next.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(24)
    }
}


