import SwiftUI

enum CaregiverTab: Hashable {
    case meds, alerts, graph, feed
}

/// Modul aparținător: patru tab-uri, fiecare cu stiva lui și titlu mare.
/// Butoanele din tab bar se găsesc în testele UI după etichetă („Medicamente”, „Alerte”, „Graf”, „Noutăți”).
struct CaregiverRoot: View {
    @State private var tab: CaregiverTab = .meds
    @State private var graphPath: [CaregiverRoute] = []
    /// sursa tranziției zoom card → detaliu din tab-ul Alerte
    @Namespace private var alertsZoom

    var body: some View {
        TabView(selection: $tab) {
            Tab("Medicamente", systemImage: "pills", value: CaregiverTab.meds) {
                NavigationStack {
                    MedsListView(showAlerts: { tab = .alerts })
                        .caregiverDestinations()
                }
                .accessibilityIdentifier("tab.meds")
            }
            Tab("Alerte", systemImage: "exclamationmark.triangle", value: CaregiverTab.alerts) {
                NavigationStack {
                    AlertsView(zoom: alertsZoom)
                        .caregiverDestinations(zoom: alertsZoom)
                }
                .accessibilityIdentifier("tab.alerts")
            }
            Tab("Graf", systemImage: "point.3.connected.trianglepath.dotted", value: CaregiverTab.graph) {
                NavigationStack(path: $graphPath) {
                    GraphView(open: { graphPath.append($0) })
                        .caregiverDestinations()
                }
                .accessibilityIdentifier("tab.graph")
            }
            Tab("Noutăți", systemImage: "bell", value: CaregiverTab.feed) {
                NavigationStack { FeedPlaceholderView() }
                    .accessibilityIdentifier("tab.feed")
            }
        }
    }
}

/// Noutățile vin la A5 (polling la 10 s pe /feed).
struct FeedPlaceholderView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Nicio noutate încă", systemImage: "bell")
        } description: {
            Text("Aici apar dozele luate sau ratate și ce v-a spus \(store.patient?.name ?? "pacientul").")
        }
        .accessibilityIdentifier("feed.placeholder")
        .navigationTitle("Noutăți")
        .navigationBarTitleDisplayMode(.large)
        .pgSettingsToolbar()
    }
}
