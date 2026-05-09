import Foundation

final class OCRService {
    static let shared = OCRService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    private func modelConfig() -> (url: String, key: String, model: String) {
        let d = UserDefaults.standard
        return (
            d.string(forKey: "model_base_url") ?? "http://127.0.0.1:8000/v1",
            d.string(forKey: "model_api_key") ?? "",
            d.string(forKey: "model_id") ?? "GLM-OCR-bf16"
        )
    }

    func recognize(imagePath: String, mode: OCRMode) async throws -> OCRResponse {
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) else {
            throw OCRError.networkError("无法读取截图文件")
        }

        let base64 = imageData.base64EncodedString()
        let cfg = modelConfig()
        let isTable = (mode == .table)

        let requestBody: [String: Any] = [
            "model": cfg.model,
            "messages": [
                [
                    "role": "user",
                    "content": isTable
                        ? [["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]]]
                        : [
                            ["type": "text", "text": "请识别并提取图片中的所有文字内容，保持原有格式和换行。只输出文字内容，不要添加额外说明。"],
                            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                        ],
                ]
            ],
            "max_tokens": isTable ? 4096 : 2048,
            "temperature": 0,
        ]

        let chatURL = URL(string: "\(cfg.url)/chat/completions")!
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cfg.key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? ""
            throw OCRError.serverError("\(httpResponse.statusCode): \(errBody.prefix(200))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OCRError.invalidResponse
        }

        let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if isTable {
            let html = wrapAsHTML(raw)
            let rowCount = countRows(raw)
            return OCRResponse(
                text: "表格识别结果，共 \(rowCount) 行数据",
                tableHTML: html,
                mode: "table",
                confidence: nil
            )
        } else {
            return OCRResponse(
                text: raw,
                tableHTML: nil,
                mode: "ocr",
                confidence: nil
            )
        }
    }

    private func wrapAsHTML(_ raw: String) -> String {
        if raw.lowercased().contains("<table") {
            return raw
        }

        if raw.lowercased().contains("<tr") || raw.lowercased().contains("<td") || raw.lowercased().contains("<th") {
            return "<table>\(raw)</table>"
        }

        let lines = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var html = "<table>"
        if lines.count > 1 {
            html += "<thead><tr>"
            let headerCells = lines.first!.components(separatedBy: "\t")
            for cell in headerCells {
                html += "<th>\(cell.trimmingCharacters(in: .whitespaces).xmlEscaped)</th>"
            }
            html += "</tr></thead><tbody>"
            for line in lines.dropFirst() {
                let cells = line.components(separatedBy: "\t")
                html += "<tr>"
                for cell in cells {
                    html += "<td>\(cell.trimmingCharacters(in: .whitespaces).xmlEscaped)</td>"
                }
                html += "</tr>"
            }
            html += "</tbody>"
        } else {
            html += "<tr><td>\(raw.xmlEscaped)</td></tr>"
        }
        html += "</table>"
        return html
    }

    private func countRows(_ raw: String) -> Int {
        let lines = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return max(1, lines.count)
    }
}

extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

enum OCRError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "模型返回无效响应，请检查模型配置"
        case .serverError(let msg):
            return "模型错误: \(msg)"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        }
    }
}
