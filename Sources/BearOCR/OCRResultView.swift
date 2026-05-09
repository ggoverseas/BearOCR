import SwiftUI
import UniformTypeIdentifiers

struct OCRResultView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0
    @State private var showCopiedToast = false
    @State private var showExporter = false
    @State private var exportURL: URL?

    private var hasTable: Bool { !appState.tableHTML.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if appState.isLoading {
                loadingView
            } else if let error = appState.lastError {
                errorView(error)
            } else {
                resultContent
            }
        }
        .frame(minWidth: 600, minHeight: 350)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在识别中...")
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

    private var resultContent: some View {
        VStack(spacing: 0) {
            toolbarRow

            if hasTable && selectedTab == 0 {
                HTMLTableView(html: appState.tableHTML)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    textContentView
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if showCopiedToast {
                Text("已复制到剪贴板")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportURL.flatMap { XLSXDocument(url: $0) },
            contentType: .xlsx,
            defaultFilename: "table_export.xlsx"
        ) { _ in
            if let url = exportURL { try? FileManager.default.removeItem(at: url) }
            exportURL = nil
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: 12) {
            if hasTable {
                Picker("", selection: $selectedTab) {
                    Text("表格").tag(0)
                    Text("源码").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            } else {
                Text("识别结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: copyToClipboard) {
                Label("复制", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("复制到剪贴板 (⌘C)")
            .keyboardShortcut("c", modifiers: .command)

            if hasTable {
                Button(action: exportXLSX) {
                    Label("导出 XLSX", systemImage: "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("导出为 Excel (.xlsx)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var textContentView: some View {
        if hasTable && selectedTab == 1 {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.ocrResultText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Divider()
                Text("HTML 源码:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.tableHTML)
                    .font(.system(.caption, design: .monospaced))
            }
        } else {
            Text(appState.ocrResultText)
                .font(.body)
        }
    }

    private func copyToClipboard() {
        let text = hasTable ? appState.tableHTML : appState.ocrResultText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }

    private func exportXLSX() {
        guard hasTable else { return }
        do {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("table_export_\(UUID().uuidString).xlsx")
            try XLSXWriter().write(html: appState.tableHTML, to: tmp)
            exportURL = tmp
            showExporter = true
        } catch {
            appState.lastError = "导出失败: \(error.localizedDescription)"
        }
    }
}

struct XLSXDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xlsx] }
    let url: URL

    init(url: URL) { self.url = url }

    init(configuration: ReadConfiguration) throws {
        fatalError("只写不支持读")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: url)
    }
}

extension UTType {
    static var xlsx: UTType {
        UTType(filenameExtension: "xlsx") ?? .data
    }
}
