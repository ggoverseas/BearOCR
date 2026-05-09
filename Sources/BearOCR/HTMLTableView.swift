import SwiftUI
import WebKit

struct HTMLTableView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 13px; padding: 12px; color: #1d1d1f; background: transparent; }
          table { border-collapse: collapse; width: 100%; }
          th { background: #f5f5f7; font-weight: 600; text-align: left; }
          th, td { padding: 6px 10px; border: 1px solid #d2d2d7; }
          tr:nth-child(even) td { background: #fafafa; }
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
        nsView.loadHTMLString(styledHTML, baseURL: nil)
    }
}
