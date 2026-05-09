import KeyboardShortcuts

enum OCRMode {
    case ocr
    case table
    case translate
}

enum AppConstants {
    static let appName = "BearOCR"
    static let baiduTranslateURL = "https://fanyi-api.baidu.com/api/trans/vip/translate"
}

extension KeyboardShortcuts.Name {
    static let ocrShortcut = Self("ocrShortcut", default: .init(.a, modifiers: [.option]))
    static let tableShortcut = Self("tableShortcut", default: .init(.t, modifiers: [.option]))
    static let translateShortcut = Self("translateShortcut", default: .init(.s, modifiers: [.option]))
}
