import SwiftUI
import AppKit

struct KeyCaptureView: NSViewRepresentable {
    let onSpace: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = KeyView()
        v.onSpace = onSpace
        DispatchQueue.main.async {
            v.window?.makeFirstResponder(v)
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? KeyView {
            v.onSpace = onSpace
            DispatchQueue.main.async {
                v.window?.makeFirstResponder(v)
            }
        }
    }

    final class KeyView: NSView {
        var onSpace: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            // 49 is spacebar
            if event.keyCode == 49 {
                onSpace?()
                return
            }
            super.keyDown(with: event)
        }
    }
}


