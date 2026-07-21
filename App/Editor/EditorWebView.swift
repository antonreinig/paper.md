import AppKit
import OSLog
import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    @ObservedObject var session: DocumentSession
    let initialScrollPosition: CGFloat
    let onScrollPositionChanged: (CGFloat) -> Void
    let onHeadingsChanged: ([DocumentHeading]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            session: session,
            initialScrollPosition: initialScrollPosition,
            onScrollPositionChanged: onScrollPositionChanged,
            onHeadingsChanged: onHeadingsChanged
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(WKUserScript(
            source: """
            window.addEventListener('error', event => {
              window.webkit.messageHandlers.editorError.postMessage({ message: event.message || 'Unknown JavaScript error' })
            })
            window.addEventListener('unhandledrejection', event => {
              window.webkit.messageHandlers.editorError.postMessage({ message: String(event.reason || 'Unhandled JavaScript rejection') })
            })
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
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
        coordinator.saveScrollPosition(from: webView)
        coordinator.stop()
        webView.stopLoading()
        for name in Coordinator.messageNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageNames = ["ready", "documentChanged", "selectionChanged", "headingsChanged", "openLink", "editorError"]
        private let logger = Logger(subsystem: "com.antonreinig.PaperMD", category: "EditorBridge")
        weak var webView: WKWebView?
        var session: DocumentSession
        private var isReady = false
        private var lastLoadedMarkdown: String?
        private var hasLoadedDocument = false
        private let initialScrollPosition: CGFloat
        private let onScrollPositionChanged: (CGFloat) -> Void
        private let onHeadingsChanged: ([DocumentHeading]) -> Void

        init(
            session: DocumentSession,
            initialScrollPosition: CGFloat,
            onScrollPositionChanged: @escaping (CGFloat) -> Void,
            onHeadingsChanged: @escaping ([DocumentHeading]) -> Void
        ) {
            self.session = session
            self.initialScrollPosition = initialScrollPosition
            self.onScrollPositionChanged = onScrollPositionChanged
            self.onHeadingsChanged = onHeadingsChanged
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
            let scrollPosition = hasLoadedDocument ? currentScrollPosition : initialScrollPosition
            let script = "window.editorBridge.loadMarkdown(\(argument), \(scrollPosition))"
            webView?.evaluateJavaScript(script) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let confirmed = result as? String,
                       markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !confirmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.lastLoadedMarkdown = markdown
                        self.hasLoadedDocument = true
                        self.logger.info("Editor confirmed document load (source: \(markdown.count), serialized: \(confirmed.count) characters)")
                    } else {
                        if let error { self.logger.error("Editor load failed: \(error.localizedDescription, privacy: .public)") }
                        try? await Task.sleep(for: .milliseconds(50))
                        guard self.lastLoadedMarkdown != markdown else { return }
                        self.webView?.evaluateJavaScript(script) { retryResult, retryError in
                            if let confirmed = retryResult as? String,
                               markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || !confirmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                self.lastLoadedMarkdown = markdown
                                self.hasLoadedDocument = true
                                self.logger.info("Editor confirmed document load after retry (serialized: \(confirmed.count) characters)")
                            } else {
                                self.logger.error("Editor did not confirm document load: \(retryError?.localizedDescription ?? "empty result", privacy: .public)")
                                self.session.errorMessage = "The editor could not display this Markdown document."
                            }
                        }
                    }
                }
            }
        }

        func saveScrollPosition(from webView: WKWebView) {
            onScrollPositionChanged(scrollPosition(in: webView) ?? 0)
        }

        private var currentScrollPosition: CGFloat {
            webView.flatMap { scrollPosition(in: $0) } ?? initialScrollPosition
        }

        private func scrollPosition(in view: NSView) -> CGFloat? {
            if let scrollView = view as? NSScrollView {
                return scrollView.contentView.bounds.origin.y
            }
            for subview in view.subviews {
                if let position = scrollPosition(in: subview) {
                    return position
                }
            }
            return nil
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
            case "headingsChanged":
                guard let body = message.body as? [String: Any],
                      let values = body["headings"] as? [[String: Any]] else { return }
                let headings = values.compactMap { value -> DocumentHeading? in
                    guard let id = value["id"] as? String,
                          let title = value["title"] as? String else { return nil }
                    return DocumentHeading(id: id, title: title)
                }
                onHeadingsChanged(headings)
            case "openLink":
                guard let body = message.body as? [String: Any],
                      let value = body["url"] as? String else { return }
                openLink(value)
            case "editorError":
                let body = message.body as? [String: Any]
                let details = body?["message"] as? String ?? "Unknown JavaScript error"
                logger.error("Editor JavaScript error: \(details, privacy: .public)")
                session.errorMessage = "The editor failed to start: \(details)"
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            logger.info("Editor page finished loading")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            logger.error("Editor navigation failed: \(error.localizedDescription, privacy: .public)")
            session.errorMessage = "The editor page could not be loaded: \(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            logger.error("Editor provisional navigation failed: \(error.localizedDescription, privacy: .public)")
            session.errorMessage = "The editor page could not be loaded: \(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { return .allow }
            openLink(url.absoluteString)
            return .cancel
        }

        private func openLink(_ value: String) {
            guard let destination = EditorLinkResolver.resolve(
                value,
                documentURL: session.url,
                workspaceRootURL: session.workspaceRootURL
            ) else { return }

            switch destination {
            case .anchor(let fragment):
                guard let argument = Self.javaScriptArgument(fragment) else { return }
                webView?.evaluateJavaScript("document.getElementById(\(argument))?.scrollIntoView({ behavior: 'smooth', block: 'start' })")
            case .external(let url), .localFile(let url):
                NSWorkspace.shared.open(url)
            }
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
