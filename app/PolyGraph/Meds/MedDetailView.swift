import Foundation
import SwiftUI

/// Detaliul unui medicament (aparținător): poza mare, substanțele, momentele din program, alertele lui.
/// „Editează” deschide sheet-ul de confirmare de la scanare (A2), în modul de editare.
struct MedDetailView: View {
    let medID: String

    @Environment(AppStore.self) private var store
    @State private var editing: ScanConfirmation?

    var body: some View {
        Group {
            if let med = store.med(id: medID) {
                content(med)
            } else {
                ContentUnavailableView(
                    "Medicamentul nu mai e în listă",
                    systemImage: "pills",
                    description: Text("A fost șters între timp."))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("medDetail")
    }

    private func content(_ med: MedicationItem) -> some View {
        List {
            photoSection(med)

            Section {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(med.displayName)
                        .font(.title2.weight(.semibold))
                    Text(PgFormat.dosageWords(med.dosage))
                        .foregroundStyle(.secondary)
                    if let raw = med.dosage.raw, !raw.isEmpty {
                        Text("Pe rețetă: „\(raw)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                LabeledContent("Prescris de", value: prescriberText(med.prescriber))
                if let food = med.dosage.withFood.instruction {
                    LabeledContent("Cu masa", value: food)
                }
                if let expiry = med.product.expiry {
                    LabeledContent("Expiră", value: expiry)
                }
            }

            Section("Substanțe active") {
                if med.substances.isEmpty {
                    Text("Nu știm încă substanța activă. Apăsați „Editează” și căutați-o în catalog.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(med.substances.enumerated()), id: \.offset) { _, substance in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(substance.displayName ?? "Substanță necunoscută")
                            Text(substanceDetail(substance))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .accessibilityIdentifier("medDetail.substances")

            let moments = scheduleMoments(for: med.id)
            if !moments.isEmpty {
                Section("În programul de azi") {
                    ForEach(moments, id: \.time) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                            Text(entry.time)
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(PgFormat.doseAmount(entry.dose.qty)) · \(entry.label)")
                                if !entry.dose.instruction.isEmpty {
                                    Text(entry.dose.instruction)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .accessibilityIdentifier("medDetail.schedule")
            }

            let alerts = (store.analysis?.alerts ?? []).shownInApp
                .filter { $0.medids.contains(med.id) }
                .sortedBySeverity()
            Section("Alerte") {
                if alerts.isEmpty {
                    Text("Nicio alertă pentru acest medicament.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alerts) { alert in
                        NavigationLink(value: CaregiverRoute.alert(id: alert.id, zoom: false)) {
                            CompactAlertRow(alert: alert)
                        }
                        .accessibilityIdentifier("medDetail.alert.\(alert.id)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editează") {
                    editing = ScanConfirmation(
                        result: ExtractionResult(candidates: [med], rawText: nil, warnings: []),
                        photo: nil,
                        kind: .box,
                        ocrLines: [],
                        datamatrix: nil)
                }
                .accessibilityIdentifier("medDetail.editButton")
            }
        }
        .sheet(item: $editing) { confirmation in
            ConfirmSheet(confirmation: confirmation, editingID: med.id) { _ in
                editing = nil
            }
            .environment(store)
        }
    }

    @ViewBuilder
    private func photoSection(_ med: MedicationItem) -> some View {
        if let url = store.api.mediaURL(med.photourl) {
            Section {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityLabel("Poza cutiei")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func prescriberText(_ prescriber: Prescriber) -> String {
        let specialty = prescriber.specialty.map { $0.prefix(1).uppercased(with: PgFormat.romanian) + $0.dropFirst() }
        switch (prescriber.name, specialty) {
        case let (name?, specialty?): return "\(name), \(specialty)"
        case let (name?, nil): return name
        case let (nil, specialty?): return specialty
        case (nil, nil): return MedSection.withoutPrescription
        }
    }

    private func substanceDetail(_ substance: Substance) -> String {
        var parts: [String] = []
        if let mg = substance.strengthMg {
            parts.append("\(mg.formatted(.number.precision(.fractionLength(0...2)).locale(PgFormat.romanian))) mg")
        }
        parts.append(substance.atc.map { "ATC \($0)" } ?? "fără cod ATC")
        return parts.joined(separator: " · ")
    }

    private struct MomentEntry {
        let time: String
        let label: String
        let dose: DoseElement
    }

    private func scheduleMoments(for medID: String) -> [MomentEntry] {
        (store.schedule?.moments ?? []).flatMap { moment in
            moment.doses
                .filter { $0.medid == medID }
                .map { MomentEntry(time: moment.time, label: moment.label, dose: $0) }
        }
    }
}

extension WithFood {
    /// Pentru detaliul medicamentului; „oricând” nu se mai scrie.
    var instruction: String? {
        switch self {
        case .emptyStomach: "Pe stomacul gol"
        case .beforeMeal: "Înainte de masă"
        case .withMeal: "La masă"
        case .afterMeal: "După masă"
        case .any: nil
        }
    }
}
