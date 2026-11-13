import SwiftUI

/// Placeholder pentru ecranul de alerte (cardurile și detaliul vin la A3).
struct AlertsPlaceholderView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Alertele apar aici", systemImage: "exclamationmark.triangle")
        } description: {
            if let analysis = store.analysis {
                Text("Am găsit \(analysis.alerts.count) observații pentru medicamentele din listă.")
            } else {
                Text("După ce se încarcă lista de medicamente.")
            }
        }
        .accessibilityIdentifier("alerts.placeholder")
        .navigationTitle("Alerte")
        .navigationBarTitleDisplayMode(.large)
        .pgSettingsToolbar()
    }
}
