import Foundation
import CommonCrypto

final class TranslationService {
    static let shared = TranslationService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    func translate(text: String, appID: String, secretKey: String) async throws -> String {
        guard !appID.isEmpty, !secretKey.isEmpty else {
            throw TranslationError.missingCredentials
        }

        let salt = String(Int.random(in: 10000...99999))
        let sign = generateSign(text: text, appID: appID, salt: salt, secretKey: secretKey)

        let detectedLang = detectLanguage(text: text)
        let targetLang: String = detectedLang == "zh" ? "en" : "zh"

        var components = URLComponents(string: AppConstants.baiduTranslateURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "from", value: "auto"),
            URLQueryItem(name: "to", value: targetLang),
            URLQueryItem(name: "appid", value: appID),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "sign", value: sign)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let err = String(data: data, encoding: .utf8) {
                throw TranslationError.apiError(err)
            }
            throw TranslationError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(BaiduTranslateResponse.self, from: data)

        if let errorCode = result.errorCode, errorCode != "52000" {
            throw TranslationError.apiError("错误码 \(errorCode): \(result.errorMsg ?? "")")
        }

        let translated = result.transResult?.map { $0.dst }.joined(separator: "\n") ?? ""
        return translated
    }

    private func generateSign(text: String, appID: String, salt: String, secretKey: String) -> String {
        let signString = "\(appID)\(text)\(salt)\(secretKey)"
        return md5(signString)
    }

    private func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func detectLanguage(text: String) -> String {
        let chinesePattern = try? NSRegularExpression(pattern: "[\\u4e00-\\u9fff]+")
        let chineseRange = NSRange(text.startIndex..., in: text)
        guard let pattern = chinesePattern,
              let _ = pattern.firstMatch(in: text, range: chineseRange) else {
            return "en"
        }
        return "zh"
    }
}

enum TranslationError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "请在设置中配置百度翻译 API 的 App ID 和 Secret Key"
        case .invalidResponse:
            return "翻译服务返回无效响应"
        case .apiError(let msg):
            return "翻译 API 错误: \(msg)"
        }
    }
}

private struct BaiduTranslateResponse: Codable {
    let from: String?
    let to: String?
    let transResult: [BaiduTransItem]?
    let errorCode: String?
    let errorMsg: String?

    enum CodingKeys: String, CodingKey {
        case from, to
        case transResult = "trans_result"
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }
}

private struct BaiduTransItem: Codable {
    let src: String
    let dst: String
}
