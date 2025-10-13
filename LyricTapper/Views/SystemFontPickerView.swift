import SwiftUI
import AppKit

struct SystemFontPickerView: NSViewControllerRepresentable {
    var onPick: (String) -> Void
    var onCancel: () -> Void

    func makeNSViewController(context: Context) -> NSViewController {
        let vc = NSViewController()
        let fontManager = NSFontManager.shared
        fontManager.target = context.coordinator
        fontManager.action = #selector(Coordinator.didPickFont(_:))
        DispatchQueue.main.async {
            fontManager.orderFrontFontPanel(self)
        }
        return vc
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject {
        let onPick: (String) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        @objc func didPickFont(_ sender: NSFontManager) {
            let font = sender.selectedFont ?? NSFont.systemFont(ofSize: 24)
            let family = font.familyName ?? "System"
            onPick(family)
        }
    }
}


