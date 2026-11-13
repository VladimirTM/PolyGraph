import SwiftUI

/// Placeholder pentru graf (WKWebView pe /share/{token}/graph vine la A3).
struct GraphPlaceholderView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Graful apare aici", systemImage: "point.3.connected.trianglepath.dotted")
        } description: {
            if let graph = store.analysis?.graph {
                Text("\(graph.nodes.count) noduri și \(graph.edges.count) legături între medicamente.")
            } else {
                Text("Legăturile dintre medicamente, desenate ca o hartă.")
            }
        }
        .accessibilityIdentifier("graph.placeholder")
        .navigationTitle("Graf")
        .navigationBarTitleDisplayMode(.large)
        .pgSettingsToolbar()
    }
}
