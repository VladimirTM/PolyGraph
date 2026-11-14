import Foundation
import SwiftUI

/// Alertele pacientului (aparținător): câte un card pentru fiecare alertă gravă, apoi cele moderate și
/// mâncarea, restrânse, apoi cardul ACB (aceeași ordine ca fișa din portal). Cardurile se deschid cu tranziție zoom.
struct AlertsView: View {
    let zoom: Namespace.ID

    @Environment(AppStore.self) private var store

    var body: some View {
        content
            .navigationTitle("Alerte")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await store.refreshAll() }
            .pgSettingsToolbar()
    }

    @ViewBuilder
    private var content: some View {
        if let analysis = store.analysis {
            let sections = AlertSections(analysis.alerts)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.s) {
                    if sections.isEmpty {
                        ContentUnavailableView(
                            "Nicio alertă",
                            systemImage: "checkmark.shield",
                            description: Text("Nu am găsit interacțiuni de discutat pentru medicamentele din listă."))
                            .accessibilityIdentifier("alerts.empty")
                    }
                    ForEach(sections.serious) { alert in
                        NavigationLink(value: CaregiverRoute.alert(id: alert.id, zoom: true)) {
                            AlertCard(alert: alert)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .matchedTransitionSource(id: alert.id, in: zoom)
                        .accessibilityIdentifier("alerts.card.\(alert.id)")
                    }
                    if !sections.moderate.isEmpty {
                        AlertGroupCard(
                            title: sections.moderateSummary,
                            systemImage: "list.bullet.clipboard",
                            alerts: sections.moderate,
                            zoom: zoom
                        )
                        .accessibilityIdentifier("alerts.moderateGroup")
                    }
                    if !sections.food.isEmpty {
                        AlertGroupCard(
                            title: "Mâncare și băutură",
                            systemImage: "fork.knife",
                            alerts: sections.food,
                            zoom: zoom
                        )
                        .accessibilityIdentifier("alerts.foodGroup")
                    }
                    // ultimul, ca în fișa din portal: grave → moderate → mâncare → ACB (Q3-17)
                    if analysis.acbTotal >= 1 {
                        AcbCard(total: analysis.acbTotal, alerts: analysis.alerts)
                    }
                    Text("Alertele minore apar doar în portalul medicului de familie.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.l)
                .pgAnimation(.pgStandard, value: analysis.alerts.map(\.id))
            }
            .background(PgColor.background)
            .accessibilityIdentifier("alerts.list")
        } else if store.isLoading {
            ProgressView("Se încarcă alertele…")
                .accessibilityIdentifier("alerts.loading")
        } else {
            ContentUnavailableView {
                Label("Alertele apar aici", systemImage: "exclamationmark.triangle")
            } description: {
                Text(store.lastError ?? "După ce se încarcă lista de medicamente.")
            } actions: {
                Button("Încearcă din nou") {
                    Task { await store.refreshAll() }
                }
                .pgProminentButton()
                .accessibilityIdentifier("alerts.retryButton")
            }
            .accessibilityIdentifier("alerts.error")
        }
    }
}

// MARK: - Cardul unei alerte

/// Punct + severitate în cuvinte, titlul, medicamentele, o linie de recomandare.
struct AlertCard: View {
    let alert: Alert

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SeverityDot(severity: alert.severity)
                Text(alert.severity.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(alert.severity.color)
                if alert.isByAnalogy {
                    Text("prin analogie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.5)))
                }
                Spacer(minLength: 0)
                if alert.status == .reviewedByDoctor {
                    Label("Revizuită", systemImage: "checkmark.seal.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(PgColor.accent)
                        .accessibilityLabel("Revizuită de medicul de familie")
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            Text(alert.title)
                .font(.headline)
                .foregroundStyle(PgColor.textPrimary)
                .multilineTextAlignment(.leading)
            if !medNames.isEmpty {
                FlowChips(names: medNames)
            }
            Text(alert.recommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PgColor.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Deschide detaliile alertei")
    }

    private var medNames: [String] {
        alert.medids.compactMap { store.med(id: $0)?.product.brand }
    }
}

/// Chip-urile medicamentelor; trec pe rândul următor dacă nu încap (Dynamic Type mare).
struct FlowChips: View {
    let names: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xxs) { chips }
            VStack(alignment: .leading, spacing: Spacing.xxs) { chips }
        }
    }

    private var chips: some View {
        ForEach(names, id: \.self) { MedChip(name: $0) }
    }
}

// MARK: - Cardurile restrânse

/// Un card restrâns pentru mai multe alerte (moderate, mâncare); se deschide cu DisclosureGroup.
private struct AlertGroupCard: View {
    let title: String
    let systemImage: String
    let alerts: [Alert]
    let zoom: Namespace.ID

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded.animation(PgMotion.resolve(.pgStandard, reduceMotion: PgMotion.isReduceMotionEnabled))) {
            VStack(spacing: 0) {
                ForEach(alerts) { alert in
                    Divider()
                    NavigationLink(value: CaregiverRoute.alert(id: alert.id, zoom: true)) {
                        CompactAlertRow(alert: alert)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .matchedTransitionSource(id: alert.id, in: zoom)
                    .accessibilityIdentifier("alerts.card.\(alert.id)")
                }
            }
            .padding(.top, Spacing.xs)
        } label: {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PgColor.textPrimary)
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(PgColor.accent)
            }
        }
        .tint(PgColor.textSecondary)
        .padding(Spacing.m)
        .background(PgColor.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// Un rând dintr-un card restrâns: punct + severitate, titlul, medicamentele.
/// În `List` (detaliul medicamentului) sistemul pune deja chevronul, deci `showsChevron: false` (Q3-29).
struct CompactAlertRow: View {
    let alert: Alert
    var showsChevron = true

    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            SeverityDot(severity: alert.severity, size: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PgColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let names = alert.medids.compactMap { store.med(id: $0)?.product.brand }.joined(separator: ", ")
        let parts = [alert.severity.label, names, alert.isByAnalogy ? "prin analogie" : nil]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
