import Foundation
import OSLog
import SwiftUI
import UIKit
import WebKit

/// Graful terapeutic (aparținător). Până la B6, pagina e `graph.html` din bundle (cu `cytoscape.min.js`
/// local, fără internet) și primește graful din `/analysis`; după B6, `{baseURL}/share/{token}/graph?embed=1`.
/// Atingerea unei muchii colorate deschide alerta; a unui medicament, detaliul lui.
struct GraphView: View {
    /// Se trece pe `true` când pagina lui B6 e în `main`.
    static let usesSharePage = false

    let open: (CaregiverRoute) -> Void

    @Environment(AppStore.self) private var store
    @State private var remoteURL: URL?

    var body: some View {
        content
            .navigationTitle("Graf")
            .navigationBarTitleDisplayMode(.inline)
            .pgSettingsToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if let graph = store.analysis?.graph {
            GraphWebView(source: source(graph), onMessage: handle)
                .ignoresSafeArea(edges: .bottom)
                .background(PgColor.background)
                .overlay(alignment: .bottomLeading) { legend }
                .accessibilityIdentifier("graph.web")
                .task(id: Self.usesSharePage) {
                    guard Self.usesSharePage, remoteURL == nil else { return }
                    do {
                        let token = try await store.ensureShareToken()
                        remoteURL = store.api.shareGraphURL(token: token)
                    } catch {
                        Log.graph.error("share token: \(String(describing: error), privacy: .public)")
                    }
                }
        } else if store.isLoading {
            ProgressView("Se încarcă graful…")
                .accessibilityIdentifier("graph.loading")
        } else {
            ContentUnavailableView {
                Label("Graful apare aici", systemImage: "point.3.connected.trianglepath.dotted")
            } description: {
                Text(store.lastError ?? "Legăturile dintre medicamente, desenate ca o hartă.")
            }
            .accessibilityIdentifier("graph.empty")
        }
    }

    private func source(_ graph: Graph) -> GraphWebView.Source {
        if Self.usesSharePage, let remoteURL { return .remote(remoteURL) }
        return .bundled(graph)
    }

    private func handle(_ message: GraphWebView.Message) {
        switch message {
        case .alert(let id) where store.alert(id: id) != nil:
            open(.alert(id: id, zoom: false))
        case .med(let id) where store.med(id: id) != nil:
            open(.med(id: id))
        default:
            break
        }
    }

    /// Severitatea e spusă în cuvinte și în graf, nu doar prin culoare.
    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            legendRow(.major, "Gravă")
            legendRow(.moderate, "Moderată")
            legendRow(.minor, "Fără nivel cunoscut")
            Text("Atingeți o legătură colorată")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("graph.legend")
    }

    private func legendRow(_ severity: Severity, _ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Capsule()
                .fill(severity.color)
                .frame(width: 18, height: 4)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - WKWebView

struct GraphWebView: UIViewRepresentable {
    enum Source: Equatable {
        case bundled(Graph)
        case remote(URL)

        static func == (lhs: Source, rhs: Source) -> Bool {
            switch (lhs, rhs) {
            case let (.remote(a), .remote(b)): a == b
            case let (.bundled(a), .bundled(b)): GraphWebView.json(a) == GraphWebView.json(b)
            default: false
            }
        }
    }

    enum Message {
        case alert(String)
        case med(String)
    }

    /// numele handler-elor din pagină (aceleași în `graph.html` și în pagina lui B6)
    static let handlerNames = ["alert", "med", "ready"]

    let source: Source
    let onMessage: (Message) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        for name in Self.handlerNames {
            configuration.userContentController.add(context.coordinator, name: name)
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        // Cytoscape face singur pan și zoom
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.load(source)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onMessage = onMessage
        context.coordinator.load(source)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        for name in handlerNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
    }

    static func json(_ graph: Graph) -> String {
        (try? JSONCoding.encoder.encode(graph)).map { String(decoding: $0, as: UTF8.self) } ?? "{\"nodes\":[],\"edges\":[]}"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onMessage: (Message) -> Void
        weak var webView: WKWebView?
        private var loaded: Source?
        private var pageReady = false
        private var pendingJSON: String?
        private var startedAt = Date()

        init(onMessage: @escaping (Message) -> Void) {
            self.onMessage = onMessage
        }

        func load(_ source: Source) {
            guard source != loaded, let webView else { return }
            switch (source, loaded) {
            case (.bundled(let graph), .some(.bundled)) where pageReady:
                // aceeași pagină, alt graf: doar se redesenează
                loaded = source
                render(GraphWebView.json(graph))
            case (.bundled(let graph), _):
                loaded = source
                pendingJSON = GraphWebView.json(graph)
                pageReady = false
                startedAt = Date()
                guard let url = Bundle.main.url(forResource: "graph", withExtension: "html") else {
                    Log.graph.error("graph.html lipsește din bundle")
                    return
                }
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            case (.remote(let url), _):
                loaded = source
                pendingJSON = nil
                startedAt = Date()
                webView.load(URLRequest(url: url))
            }
        }

        private func render(_ json: String) {
            webView?.evaluateJavaScript("window.pgRender(\(json))") { _, error in
                if let error {
                    Log.graph.error("pgRender: \(String(describing: error), privacy: .public)")
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
            if let json = pendingJSON {
                pendingJSON = nil
                render(json)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            Log.graph.error("graful nu s-a încărcat: \(String(describing: error), privacy: .public)")
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "alert":
                if let id = message.body as? String { onMessage(.alert(id)) }
            case "med":
                if let id = message.body as? String { onMessage(.med(id)) }
            case "ready":
                let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
                Log.graph.info("graf desenat în \(ms, privacy: .public) ms")
            default:
                break
            }
        }
    }
}
