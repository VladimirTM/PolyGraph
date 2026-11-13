import SwiftUI
import UIKit

/// Lista de medicamente (aparținător): secțiuni pe medic, swipe-to-delete cu „Anulează” 5 s,
/// adăugarea prin cameră, detaliul la atingere.
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
                if let pending = store.deletions.pending {
                    undoBanner(pending)
                        .transition(PgMotion.transition(
                            .move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
                } else if let completion {
                    completionBanner(completion)
                        .transition(PgMotion.transition(
                            .move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
                }
            }
            .sensoryFeedback(.success, trigger: completion) { _, new in new != nil }
            .sensoryFeedback(.error, trigger: store.deletions.lastError) { _, new in new != nil }
            .task(id: completion) {
                guard completion != nil else { return }
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                withPgAnimation(.pgStandard) { completion = nil }
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.visibleMeds.isEmpty && store.deletions.pending == nil {
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
            List {
                if let error = store.deletions.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("meds.deleteError")
                    }
                }
                ForEach(MedSection.group(store.visibleMeds)) { section in
                    Section(section.title) {
                        ForEach(section.meds) { med in
                            NavigationLink(value: CaregiverRoute.med(id: med.id)) {
                                MedRow(med: med, worst: store.analysis?.alerts.worst(forMed: med.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.deletions.schedule(id: med.id, name: med.displayName)
                                } label: {
                                    Label("Șterge", systemImage: "trash")
                                }
                                .accessibilityIdentifier("meds.deleteButton.\(med.id)")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("meds.list")
        }
    }

    /// „Am șters Sintrom 4 mg.” + „Anulează”, 5 s; DELETE pleacă abia după (agency, fără dialog).
    private func undoBanner(_ pending: DeleteUndoQueue.Pending) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Am șters \(pending.name).")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Anulează") {
                store.deletions.undo()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("meds.undoButton")
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.s)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meds.undoBanner")
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

/// Poza cutiei, numele și concentrația, posologia în cuvinte, cea mai gravă alertă.
private struct MedRow: View {
    let med: MedicationItem
    let worst: Alert?

    @Environment(AppStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var thumbnail: CGFloat = 48

    var body: some View {
        HStack(spacing: Spacing.s) {
            photo
            VStack(alignment: .leading, spacing: 2) {
                Text(med.displayName)
                    .font(.headline)
                Text(PgFormat.dosageWords(med.dosage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let worst {
                    HStack(spacing: Spacing.xxs) {
                        SeverityDot(severity: worst.severity, size: 8)
                        Text("\(worst.severity.label): \(worst.title)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityIdentifier("meds.row.\(med.id).alert")
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("meds.row.\(med.id)")
    }

    private var photo: some View {
        AsyncImage(url: store.api.mediaURL(med.photourl)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "pills")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
        }
        .frame(width: thumbnail, height: thumbnail)
        .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
        .accessibilityHidden(true)
    }
}
