import SwiftUI
import KeyboardShortcuts
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            hotkeySettings
                .tabItem { Label("快捷键", systemImage: "command") }

            modelSettings
                .tabItem { Label("模型", systemImage: "brain") }

            translationSettings
                .tabItem { Label("翻译", systemImage: "globe") }
        }
        .scenePadding()
        .frame(width: 440, height: 350)
    }

    private var hotkeySettings: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("全局热键（任何应用下均可触发）")
                        .font(.headline)

                    ShortcutRecorderRow(
                        label: "截图识别 OCR",
                        name: .ocrShortcut
                    )

                    ShortcutRecorderRow(
                        label: "表格识别",
                        name: .tableShortcut
                    )

                    ShortcutRecorderRow(
                        label: "截图翻译",
                        name: .translateShortcut
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private var modelSettings: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LLM 模型配置").font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("请求地址 (OpenAI 兼容 API)").font(.caption).foregroundStyle(.secondary)
                        TextField("http://127.0.0.1:8000/v1", text: $appState.modelBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key").font(.caption).foregroundStyle(.secondary)
                        TextField("API Key", text: $appState.modelAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("模型 ID").font(.caption).foregroundStyle(.secondary)
                        TextField("GLM-OCR-bf16", text: $appState.modelID)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Text("支持 LM Studio / Ollama / OpenAI 等任意 OpenAI 兼容 API")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var translationSettings: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("百度翻译 API 配置").font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App ID").font(.caption).foregroundStyle(.secondary)
                        TextField("App ID", text: $appState.baiduAppID)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secret Key").font(.caption).foregroundStyle(.secondary)
                        SecureField("Secret Key", text: $appState.baiduSecretKey)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                    }
                }
                Text("注册地址: https://fanyi-api.baidu.com")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRecorderRow: View {
    let label: String
    let name: KeyboardShortcuts.Name

    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .leading)
                .font(.body)

            Button(action: startRecording) {
                Text(isRecording ? "按下快捷键..." : displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            if KeyboardShortcuts.getShortcut(for: name) != nil {
                Button("清除") {
                    KeyboardShortcuts.setShortcut(nil, for: name)
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var displayString: String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            return String(describing: shortcut)
        }
        return "未设置"
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }
            if let shortcut = KeyboardShortcuts.Shortcut(event: event) {
                KeyboardShortcuts.setShortcut(shortcut, for: self.name)
            }
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }
}
