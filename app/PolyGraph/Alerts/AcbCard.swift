import Foundation
import SwiftUI

/// Încărcarea anticolinergică (scala ACB): scorul mare, ce înseamnă și medicamentele care contribuie.
struct AcbCard: View {
    let total: Int
    let alerts: [Alert]

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Încărcarea anticolinergică")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text("\(total)")
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(severity.color)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xxs) {
                        SeverityDot(severity: severity, size: 8)
                        Text(total >= 3 ? "Scor ACB ridicat" : "Scor ACB mic")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(Self.meaning(total))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !contributors.isEmpty {
                Text("Contribuie: \(contributors.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Sursa: \(Source(db: .acb, ref: nil, url: nil).displayName)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PgColor.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("alerts.acbCard")
    }

    /// Culoarea vine din severitatea alertei anticolinergice (în fixture e `moderate`, deci portocaliu), nu din
    /// prag: cardul nu e roșu când alerta lui nu e gravă (Q3-17).
    private var severity: Severity {
        Self.severity(of: alerts)
    }

    static func severity(of alerts: [Alert]) -> Severity {
        alerts.filter { $0.kind == .anticholinergic }.map(\.severity).min { $0.rank < $1.rank } ?? .moderate
    }

    static func meaning(_ total: Int) -> String {
        total >= 3
            ? "Risc crescut de confuzie și căderi."
            : "Efect mic; contează dacă se adaugă alte medicamente de acest fel."
    }

    /// Medicamentele din alertele anticolinergice, cu numele din listă.
    private var contributors: [String] {
        var seen: Set<String> = []
        return alerts
            .filter { $0.kind == .anticholinergic }
            .flatMap(\.medids)
            .filter { seen.insert($0).inserted }
            .compactMap { store.med(id: $0)?.displayName }
    }
}
