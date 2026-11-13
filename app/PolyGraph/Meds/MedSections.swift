import Foundation

/// O secțiune din lista de medicamente: medicii, după specialitate, iar la final „Fără rețetă”.
struct MedSection: Identifiable, Equatable {
    static let withoutPrescription = "Fără rețetă"

    let title: String
    let meds: [MedicationItem]

    var id: String { title }

    static func == (lhs: MedSection, rhs: MedSection) -> Bool {
        lhs.title == rhs.title && lhs.meds.map(\.id) == rhs.meds.map(\.id)
    }

    /// Secțiunile în ordinea în care apare prima dată fiecare medic; „Fără rețetă” la final.
    /// Specialitățile se compară fără majuscule și spații la capete.
    static func group(_ meds: [MedicationItem]) -> [MedSection] {
        var order: [String] = []
        var titles: [String: String] = [:]
        var buckets: [String: [MedicationItem]] = [:]
        for med in meds {
            let specialty = med.prescriber.specialty?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = specialty.isEmpty ? "" : specialty.lowercased(with: PgFormat.romanian)
            if buckets[key] == nil {
                order.append(key)
                titles[key] = specialty.isEmpty ? withoutPrescription : capitalizedFirst(specialty)
            }
            buckets[key, default: []].append(med)
        }
        let sorted = order.filter { !$0.isEmpty } + order.filter(\.isEmpty)
        return sorted.map { MedSection(title: titles[$0] ?? withoutPrescription, meds: buckets[$0] ?? []) }
    }

    /// „medicină de familie” → „Medicină de familie”
    private static func capitalizedFirst(_ text: String) -> String {
        text.prefix(1).uppercased(with: PgFormat.romanian) + text.dropFirst()
    }
}

extension PgFormat {
    /// Posologia în cuvinte: „½ seara”, „1 dimineața, 1 seara”, „la nevoie”.
    static func dosageWords(_ dosage: Dosage) -> String {
        let pattern = dosage.pattern
        let parts = [
            (pattern.morning, "dimineața"),
            (pattern.noon, "la prânz"),
            (pattern.evening, "seara"),
            (pattern.bedtime, "la culcare"),
        ]
        .filter { $0.0 > 0 }
        .map { "\(doseAmount($0.0)) \($0.1)" }
        if parts.isEmpty {
            return dosage.asNeeded ? "La nevoie" : "Posologie necompletată"
        }
        let text = parts.joined(separator: ", ")
        return dosage.asNeeded ? "\(text), la nevoie" : text
    }
}
