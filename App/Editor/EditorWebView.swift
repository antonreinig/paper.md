import AppKit
import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    @ObservedObject var session: DocumentSession

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        for name in Coordinator.messageNames {
            configuration.userContentController.add(context.coordinator, name: name)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            context.coordinator.reportMissingEditor()
            return webView
        }
        webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.session = session
        context.coordinator.loadMarkdownIfReady(session.content)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
        webView.stopLoading()
        for name in Coordinator.messageNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageNames = ["ready", "documentChanged", "selectionChanged", "openLink"]
        weak var webView: WKWebView?
        var session: DocumentSession
        private var isReady = false
        private var lastLoadedMarkdown: String?

        init(session: DocumentSession) {
            self.session = session
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(receiveEditorCommand(_:)),
                name: .editorCommand,
                object: nil
            )
        }

        func stop() {
            NotificationCenter.default.removeObserver(self)
        }

        func reportMissingEditor() {
            session.errorMessage = "The bundled editor could not be found. Run scripts/bootstrap.sh and rebuild the app."
        }

        func loadMarkdownIfReady(_ markdown: String) {
            guard isReady, markdown != lastLoadedMarkdown else { return }
            guard let argument = Self.javaScriptArgument(markdown) else { return }
            lastLoadedMarkdown = markdown
            webView?.evaluateJavaScript("window.editorBridge.loadMarkdown(\(argument))")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "ready":
                isReady = true
                loadMarkdownIfReady(session.content)
            case "documentChanged":
                guard let body = message.body as? [String: Any], let markdown = body["markdown"] as? String else { return }
                lastLoadedMarkdown = markdown
                session.editorChanged(markdown)
            case "openLink":
                guard let body = message.body as? [String: Any],
                      let value = body["url"] as? String,
                      let url = URL(string: value),
                      ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return }
                NSWorkspace.shared.open(url)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { return .allow }
            if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
            return .cancel
        }

        @objc private func receiveEditorCommand(_ notification: Notification) {
            guard let command = notification.userInfo?["command"] as? String else { return }
            let payload = notification.userInfo?["payload"] as? [String: String] ?? [:]
            guard let commandArgument = Self.javaScriptArgument(command),
                  let payloadData = try? JSONSerialization.data(withJSONObject: payload),
                  let payloadArgument = String(data: payloadData, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("window.editorBridge.perform(\(commandArgument), \(payloadArgument))")
        }

        private static func javaScriptArgument(_ string: String) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: [string]),
                  var array = String(data: data, encoding: .utf8) else { return nil }
            array.removeFirst()
            array.removeLast()
            return array
        }
    }
}
