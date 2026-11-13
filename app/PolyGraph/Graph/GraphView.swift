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
    /// crește la fiecare „Recentrează”; pagina revine la tot graful, centrat
    @State private var resetCount = 0
    @Environment(\.pgReduceMotion) private var reduceMotion

    var body: some View {
        content
            .navigationTitle("Graf")
            .navigationBarTitleDisplayMode(.inline)
            .pgSettingsToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if let graph = store.analysis?.graph {
            GraphWebView(
                source: source(graph), resetCount: resetCount, animateReset: !reduceMotion, onMessage: handle
            )
                .background(PgColor.background)
                .accessibilityIdentifier("graph.web")
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
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

    /// Legenda (severitatea spusă în cuvinte, nu doar prin culoare) și „Recentrează”, sub graf, ca să nu-l acopere.
    private var bottomBar: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { legendRows }
                VStack(alignment: .leading, spacing: Spacing.xxs) { legendRows }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("graph.legend")
            Spacer(minLength: 0)
            Button {
                resetCount += 1
            } label: {
                Label("Recentrează", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Recentrează graful")
            .accessibilityIdentifier("graph.resetButton")
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
    }

    @ViewBuilder
    private var legendRows: some View {
        legendRow(.major, "Gravă")
        legendRow(.moderate, "Moderată")
        legendRow(.minor, "Fără nivel cunoscut")
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
    var resetCount = 0
    var animateReset = true
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
        context.coordinator.reset(to: resetCount, animated: animateReset)
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
        private var lastReset = 0

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

        func reset(to count: Int, animated: Bool) {
            guard count != lastReset else { return }
            lastReset = count
            webView?.evaluateJavaScript("window.pgResetView && window.pgResetView(\(animated))")
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
