import Foundation

struct OCRResponse: Codable {
    let text: String
    let tableHTML: String?
    let mode: String
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case tableHTML = "table_html"
        case mode
        case confidence
    }
}

struct TranslateResponse: Codable {
    let from: String
    let to: String
    let transResult: [TransResultItem]

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case transResult = "trans_result"
    }
}

struct TransResultItem: Codable {
    let src: String
    let dst: String
}
