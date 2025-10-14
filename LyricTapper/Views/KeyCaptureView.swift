import SwiftUI
import AppKit

struct KeyCaptureView: NSViewRepresentable {
    let onSpace: () -> Void
    var onRestart: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let v = KeyView()
        v.onSpace = onSpace
        v.onRestart = onRestart
        v.onFinish = onFinish
        DispatchQueue.main.async {
            v.window?.makeFirstResponder(v)
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? KeyView {
            v.onSpace = onSpace
            v.onRestart = onRestart
            v.onFinish = onFinish
            DispatchQueue.main.async {
                v.window?.makeFirstResponder(v)
            }
        }
    }

    final class KeyView: NSView {
        var onSpace: (() -> Void)?
        var onRestart: (() -> Void)?
        var onFinish: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            // 49 = space, 15 = R, 36 = return
            switch event.keyCode {
            case 49:
                onSpace?(); return
            case 15:
                onRestart?(); return
            case 36:
                onFinish?(); return
            default:
                break
            }
            super.keyDown(with: event)
        }
    }
}


