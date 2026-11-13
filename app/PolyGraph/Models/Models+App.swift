import Foundation

// Conformanțe și texte pentru UI peste modelele generate din contracte (Contracts.swift nu se editează).

extension MedicationItem: Identifiable {}
extension Alert: Identifiable {}
extension FeedEvent: Identifiable {}
extension CheckIn: Identifiable {}

extension Moment: Identifiable {
    var id: String { time }
}

extension MedicationItem {
    /// „Sintrom 4 mg”
    var displayName: String {
        [product.brand, product.strengthText].compactMap { $0 }.joined(separator: " ")
    }

    /// „Acenocumarol”; DCI-ul din catalogul românesc e în latină și cu majuscule.
    var substanceNames: String {
        substances.displayNames
    }
}

extension Substance {
    /// „Acenocumarol”
    var displayName: String? {
        (dci ?? inn).map { $0.capitalized(with: Locale(identifier: "ro_RO")) }
    }
}

extension Array where Element == Substance {
    /// „Ibuprofen + Paracetamol”
    var displayNames: String {
        compactMap(\.displayName).joined(separator: " + ")
    }
}
