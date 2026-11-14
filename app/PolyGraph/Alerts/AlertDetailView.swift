import Foundation
import SwiftUI

/// Detaliul unei alerte: ce înseamnă, ce puteți face, medicamentele, sursa, statusul.
/// Deschis din card, crește din el (zoom); închiderea interactivă o face sistemul.
struct AlertDetailView: View {
    let alertID: String

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = 0

    var body: some View {
        Group {
            if let alert = store.alert(id: alertID) {
                content(alert)
            } else {
                ContentUnavailableView(
                    "Alerta nu mai există",
                    systemImage: "checkmark.circle",
                    description: Text("Lista de medicamente s-a schimbat și alerta nu mai e valabilă."))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: acknowledged)
        .accessibilityIdentifier("alertDetail")
    }

    private func content(_ alert: Alert) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        SeverityDot(severity: alert.severity)
                        Text(alert.severity.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(alert.severity.color)
                        if alert.isByAnalogy {
                            Text("· prin analogie")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(alert.title)
                        .font(.title2.weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("alertDetail.header")
            }

            Section("Ce înseamnă") {
                Text(alert.detail)
                    .accessibilityIdentifier("alertDetail.detail")
            }

            Section("Ce puteți face") {
                Text(alert.recommendation)
                    .accessibilityIdentifier("alertDetail.recommendation")
            }

            // analogia de clasă e spusă o singură dată, la sfârșitul lui `detail` (vine așa de la server);
            // antetul are deja „· prin analogie” (Q3-33)

            let meds = alert.medids.compactMap { store.med(id: $0) }
            if !meds.isEmpty {
                Section("Medicamentele") {
                    ForEach(meds) { med in
                        NavigationLink(value: CaregiverRoute.med(id: med.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(med.displayName)
                                if !med.substanceNames.isEmpty {
                                    Text(med.substanceNames)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("alertDetail.med.\(med.id)")
                    }
                }
            }

            Section {
                LabeledContent("Status", value: statusText(alert))
                    .accessibilityIdentifier("alertDetail.status")
                if let resolution = alert.resolution, resolution.decision != nil || !resolution.note.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(resolution.by == .doctor ? "Decizia medicului de familie" : "Nota")
                            .font(.subheadline.weight(.semibold))
                        if let decision = resolution.decision {
                            Text(decision.label)
                        }
                        if !resolution.note.isEmpty {
                            Text(resolution.note)
                        }
                        Text(resolution.at.formatted(.dateTime.day().month(.wide).hour().minute().locale(PgFormat.romanian)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("alertDetail.doctorNote")
                }
            } footer: {
                sourceFooter(alert.source)
            }

            Section {
                Button {
                    store.acknowledge(alertID: alert.id)
                    acknowledged += 1
                    dismiss()
                } label: {
                    Text("Am înțeles")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: ControlHeight.caregiver)
                }
                .pgProminentButton()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("alertDetail.understoodButton")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func statusText(_ alert: Alert) -> String {
        if alert.status == .statusOpen && store.acknowledgedAlertIDs.contains(alert.id) {
            return "Văzută de dumneavoastră"
        }
        return alert.status.label
    }

    @ViewBuilder
    private func sourceFooter(_ source: Source) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Sursa: \(source.displayName)")
            if let link = source.url.flatMap(URL.init(string:)) {
                Link("Deschide sursa", destination: link)
            }
        }
        .font(.footnote)
        .accessibilityIdentifier("alertDetail.source")
    }
}
