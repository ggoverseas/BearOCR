import SwiftUI
import AppKit
import KeyboardShortcuts

@MainActor
final class CaptureHandler {
    static let shared = CaptureHandler()

    private var ocrWindow: NSWindow?
    private var translationWindow: NSWindow?

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                if window === self.ocrWindow { self.ocrWindow = nil }
                if window === self.translationWindow { self.translationWindow = nil }
            }
        }
    }

    func captureAndRecognize(mode: OCRMode) {
        guard !AppState.shared.isLoading else { return }
        Task { await performCapture(mode: mode) }
    }

    private func performCapture(mode: OCRMode) async {
        let appState = AppState.shared
        appState.isLoading = true
        appState.lastError = nil

        let path = await ScreenshotManager.shared.captureScreenshot()
        guard let path else {
            appState.isLoading = false
            KeyboardShortcuts.Name.ocrShortcut.resetAfterScreenshotCancel()
            KeyboardShortcuts.Name.tableShortcut.resetAfterScreenshotCancel()
            KeyboardShortcuts.Name.translateShortcut.resetAfterScreenshotCancel()
            return
        }
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            let result = try await OCRService.shared.recognize(imagePath: path, mode: mode)
            switch mode {
            case .ocr:
                appState.ocrResultText = result.text
                appState.tableHTML = ""
                showOCRWindow()
            case .table:
                appState.tableHTML = result.tableHTML ?? ""
                appState.ocrResultText = result.text
                showOCRWindow()
            case .translate:
                appState.ocrResultText = result.text
                appState.tableHTML = ""
                let translated = try await TranslationService.shared.translate(
                    text: result.text, appID: appState.baiduAppID, secretKey: appState.baiduSecretKey)
                appState.translatedText = translated
                showTranslationWindow()
            }
        } catch {
            appState.lastError = error.localizedDescription
            if appState.ocrResultText.isEmpty {
                appState.ocrResultText = "识别失败: \(error.localizedDescription)"
            }
            showOCRWindow()
        }

        appState.isLoading = false
    }

    private func showOCRWindow() {
        if let existing = ocrWindow {
            existing.level = .floating
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(
            rootView: OCRResultView().environmentObject(AppState.shared))
        hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 550)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OCR 结果"
        window.contentView = hostingView
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        ocrWindow = window
    }

    private func showTranslationWindow() {
        if let existing = translationWindow {
            existing.level = .floating
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(
            rootView: TranslationResultView().environmentObject(AppState.shared))
        hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 500)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "翻译结果"
        window.contentView = hostingView
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        translationWindow = window
    }
}
