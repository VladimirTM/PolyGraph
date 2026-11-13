import SwiftUI

/// Lista de medicamente (aparținător). Scanarea, editarea și ștergerea vin la A2–A3.
struct MedsListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        content
            .navigationTitle("Medicamente")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await store.refreshAll() }
            .pgSettingsToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if store.meds.isEmpty {
            if store.isLoading {
                ProgressView("Se încarcă lista…")
                    .accessibilityIdentifier("meds.loading")
            } else if let error = store.lastError {
                ContentUnavailableView {
                    Label("Nu am putut încărca lista", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Încearcă din nou") {
                        Task { await store.refreshAll() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("meds.retryButton")
                }
                .accessibilityIdentifier("meds.error")
            } else {
                ContentUnavailableView(
                    "Niciun medicament",
                    systemImage: "pills",
                    description: Text("Medicamentele scanate apar aici."))
                .accessibilityIdentifier("meds.empty")
            }
        } else {
            List(store.meds) { med in
                MedRow(med: med)
            }
            .accessibilityIdentifier("meds.list")
        }
    }
}

private struct MedRow: View {
    let med: MedicationItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(med.displayName)
                .font(.headline)
            if !med.substanceNames.isEmpty {
                Text(med.substanceNames)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let raw = med.dosage.raw {
                Text(raw)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("meds.row.\(med.id)")
    }
}
