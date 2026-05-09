import SwiftUI

struct TranslationResultView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            if appState.isLoading {
                loadingView
            } else if let error = appState.lastError {
                errorView(error)
            } else {
                translationContent
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在识别并翻译...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var translationContent: some View {
        HSplitView {
            sourcePanel
            targetPanel
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("已复制到剪贴板")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("原文", systemImage: "text.quote")
                    .font(.headline)
                Spacer()
                Button(action: { copySourceText() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("复制原文")
            }

            ScrollView {
                Text(appState.ocrResultText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(minWidth: 220)
    }

    private var targetPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("译文", systemImage: "globe")
                    .font(.headline)
                Spacer()
                Button(action: { copyTranslatedText() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("复制译文")
            }

            ScrollView {
                Text(appState.translatedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(minWidth: 220)
    }

    private func copySourceText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.ocrResultText, forType: .string)
        showCopyToast()
    }

    private func copyTranslatedText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.translatedText, forType: .string)
        showCopyToast()
    }

    private func showCopyToast() {
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}
