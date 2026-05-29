import SwiftUI
import AppKit

/// An AppKit-backed first responder that reliably captures keyboard input for the
/// answer grid, including Tab and Shift+Tab (which SwiftUI's focus system otherwise
/// intercepts for focus traversal).
struct KeyCaptureView: NSViewRepresentable {
    var isActive: Bool
    var isLocked: Bool
    /// Returns true if the character was a valid, accepted answer letter.
    var onLetter: (String) -> Bool
    var onTab: () -> Void
    var onShiftTab: () -> Void
    var onEscape: () -> Void
    var onDelete: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        KeyCaptureNSView()
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isLocked = isLocked
        nsView.onLetter = onLetter
        nsView.onTab = onTab
        nsView.onShiftTab = onShiftTab
        nsView.onEscape = onEscape
        nsView.onDelete = onDelete
        if isActive {
            // Reclaim first responder after SwiftUI updates (e.g. after a cell click).
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                if window.firstResponder !== nsView {
                    window.makeFirstResponder(nsView)
                }
            }
        }
    }
}

final class KeyCaptureNSView: NSView {
    var isLocked = false
    var onLetter: ((String) -> Bool)?
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var onEscape: (() -> Void)?
    var onDelete: (() -> Void)?

    private enum KeyCode {
        static let tab: UInt16 = 48
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    // Keep this view out of the accessibility tree; the SwiftUI grid carries labels.
    override func isAccessibilityElement() -> Bool { false }

    override func keyDown(with event: NSEvent) {
        if isLocked { return }
        let shift = event.modifierFlags.contains(.shift)
        switch event.keyCode {
        case KeyCode.tab:
            shift ? onShiftTab?() : onTab?()
        case KeyCode.escape:
            onEscape?()
        case KeyCode.delete, KeyCode.forwardDelete:
            onDelete?()
        default:
            let characters = event.charactersIgnoringModifiers ?? ""
            if let scalar = characters.unicodeScalars.first,
               CharacterSet.letters.contains(scalar),
               onLetter?(characters) == true {
                return
            }
            // Ignore numbers, symbols and unsupported keys without a system beep.
            return
        }
    }
}
