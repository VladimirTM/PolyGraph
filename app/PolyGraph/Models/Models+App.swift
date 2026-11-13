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
        substances
            .compactMap { $0.dci ?? $0.inn }
            .map { $0.capitalized(with: Locale(identifier: "ro_RO")) }
            .joined(separator: " + ")
    }
}
