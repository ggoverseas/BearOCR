import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: { CaptureHandler.shared.captureAndRecognize(mode: .ocr) }) {
                Label("截图识别 (OCR)", systemImage: "text.viewfinder")
            }

            Button(action: { CaptureHandler.shared.captureAndRecognize(mode: .table) }) {
                Label("表格识别", systemImage: "tablecells")
            }

            Button(action: { CaptureHandler.shared.captureAndRecognize(mode: .translate) }) {
                Label("截图翻译", systemImage: "globe")
            }

            Divider()

            SettingsLink {
                Label("设置", systemImage: "gear")
            }

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("退出 BearOCR", systemImage: "power")
            }
        }
        .padding(4)
    }
}
