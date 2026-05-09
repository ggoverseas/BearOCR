import SwiftUI
import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupKeyboardShortcuts()

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            let title = window.title
            if title.hasPrefix("OCR 结果") || title.hasPrefix("翻译结果") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    KeyboardShortcuts.Name.ocrShortcut.resetAfterScreenshotCancel()
                    KeyboardShortcuts.Name.tableShortcut.resetAfterScreenshotCancel()
                    KeyboardShortcuts.Name.translateShortcut.resetAfterScreenshotCancel()
                }
            }
        }
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .ocrShortcut) {
            Task { @MainActor in CaptureHandler.shared.captureAndRecognize(mode: .ocr) }
        }
        KeyboardShortcuts.onKeyDown(for: .tableShortcut) {
            Task { @MainActor in CaptureHandler.shared.captureAndRecognize(mode: .table) }
        }
        KeyboardShortcuts.onKeyDown(for: .translateShortcut) {
            Task { @MainActor in CaptureHandler.shared.captureAndRecognize(mode: .translate) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
