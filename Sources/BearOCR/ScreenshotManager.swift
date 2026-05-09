import AppKit

final class ScreenshotManager {
    static let shared = ScreenshotManager()

    private let tempDir: URL

    private init() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.bearocr.screenshots")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    func captureScreenshot() async -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputPath = tempDir.appendingPathComponent("screenshot_\(timestamp).png").path

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/usr/sbin/screencapture"
                task.arguments = ["-i", outputPath]
                task.launch()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus)
            }
        }

        guard result == 0 else { return nil }
        guard FileManager.default.fileExists(atPath: outputPath) else { return nil }

        return outputPath
    }

    func captureFullScreen() async -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputPath = tempDir.appendingPathComponent("screenshot_full_\(timestamp).png").path

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/usr/sbin/screencapture"
                task.arguments = ["-x", outputPath]
                task.launch()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus)
            }
        }

        guard result == 0 else { return nil }
        guard FileManager.default.fileExists(atPath: outputPath) else { return nil }

        return outputPath
    }

    func cleanupTempFiles() {
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
}
