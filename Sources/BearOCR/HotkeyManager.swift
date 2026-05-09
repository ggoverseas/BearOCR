import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    func resetAfterScreenshotCancel() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: self) else { return }
        KeyboardShortcuts.setShortcut(shortcut, for: self)
    }
}
