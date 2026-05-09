import SwiftUI
import AppKit

@main
struct BearOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("BearOCR", systemImage: "text.viewfinder") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var ocrResultText: String = ""
    @Published var translatedText: String = ""
    @Published var tableHTML: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    @Published var baiduAppID: String {
        didSet { UserDefaults.standard.set(baiduAppID, forKey: "baidu_app_id") }
    }
    @Published var baiduSecretKey: String {
        didSet { UserDefaults.standard.set(baiduSecretKey, forKey: "baidu_secret_key") }
    }

    @Published var modelBaseURL: String {
        didSet { UserDefaults.standard.set(modelBaseURL, forKey: "model_base_url") }
    }
    @Published var modelAPIKey: String {
        didSet { UserDefaults.standard.set(modelAPIKey, forKey: "model_api_key") }
    }
    @Published var modelID: String {
        didSet { UserDefaults.standard.set(modelID, forKey: "model_id") }
    }

    private init() {
        let d = UserDefaults.standard

        let rawBaiduAppID = d.string(forKey: "baidu_app_id") ?? ""
        let rawBaiduSecret = d.string(forKey: "baidu_secret_key") ?? ""
        let rawModelURL = d.string(forKey: "model_base_url") ?? ""
        let rawModelKey = d.string(forKey: "model_api_key") ?? ""
        let rawModelID = d.string(forKey: "model_id") ?? ""

        baiduAppID = rawBaiduAppID
        baiduSecretKey = rawBaiduSecret
        modelBaseURL = rawModelURL.isEmpty ? "http://127.0.0.1:8000/v1" : rawModelURL
        modelAPIKey = rawModelKey
        modelID = rawModelID.isEmpty ? "GLM-OCR-bf16" : rawModelID
    }
}
