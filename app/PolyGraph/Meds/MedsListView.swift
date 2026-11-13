import SwiftUI

/// Lista de medicamente (aparținător), cu adăugarea prin cameră. Editarea și ștergerea vin la A3.
struct MedsListView: View {
    /// „Vezi” din mesajul de finalizare trece pe tab-ul Alerte
    private let showAlerts: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.pgReduceMotion) private var reduceMotion
    @State private var isScanning = false
    @State private var completion: ScanOutcome?

    init(showAlerts: @escaping () -> Void = {}) {
        self.showAlerts = showAlerts
    }

    var body: some View {
        content
            .navigationTitle("Medicamente")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await store.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isScanning = true
                    } label: {
                        Label("Adaugă medicament", systemImage: "plus")
                    }
                    .accessibilityIdentifier("meds.addButton")
                }
            }
            .pgSettingsToolbar()
            .fullScreenCover(isPresented: $isScanning) {
                ScanView { outcome in
                    withPgAnimation(.pgStandard) { completion = outcome }
                }
                .environment(store)
            }
            .overlay(alignment: .bottom) {
                if let completion {
                    completionBanner(completion)
                        .transition(PgMotion.transition(
                            .move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
                }
            }
            .sensoryFeedback(.success, trigger: completion) { _, new in new != nil }
            .task(id: completion) {
                guard completion != nil else { return }
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                withPgAnimation(.pgStandard) { completion = nil }
            }
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
                ContentUnavailableView {
                    Label("Niciun medicament", systemImage: "pills")
                } description: {
                    Text("Scanați cutia sau rețeta, iar medicamentele apar aici.")
                } actions: {
                    Button("Scanează un medicament") { isScanning = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("meds.emptyScanButton")
                }
                .accessibilityIdentifier("meds.empty")
            }
        } else {
            List(store.meds) { med in
                MedRow(med: med)
            }
            .accessibilityIdentifier("meds.list")
        }
    }

    /// Mesajul de finalizare (skill §16): ce s-a salvat și câte alerte noi a adus.
    private func completionBanner(_ outcome: ScanOutcome) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PgColor.accent)
                .accessibilityHidden(true)
            Text(Self.completionText(outcome))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if outcome.newAlerts > 0 {
                Button("Vezi") {
                    withPgAnimation(.pgStandard) { completion = nil }
                    showAlerts()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("meds.savedBanner.showAlerts")
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.s)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meds.savedBanner")
    }

    /// „Am salvat. 2 alerte noi”, „Am salvat 3 medicamente. O alertă nouă”
    static func completionText(_ outcome: ScanOutcome) -> String {
        let saved = outcome.savedCount > 1 ? "Am salvat \(PgFormat.medicationCount(outcome.savedCount))." : "Am salvat."
        let alerts =
            switch outcome.newAlerts {
            case 0: "Nicio alertă nouă"
            case 1: "O alertă nouă"
            case 2...19: "\(outcome.newAlerts) alerte noi"
            default: "\(outcome.newAlerts) de alerte noi"
            }
        return "\(saved) \(alerts)"
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
