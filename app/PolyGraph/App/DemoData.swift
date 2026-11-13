import Foundation

/// Datele scenariului demo incluse în aplicație (Setări → Mod demo).
enum DemoData {
    enum Failure: LocalizedError {
        case missing
        var errorDescription: String? { "Lipsește rețeta demo din aplicație." }
    }

    /// Rețeta ORL din scenariul „medic nou” (Fromilid, claritromicină). Copia din `Resources/` trebuie
    /// să rămână identică cu `contracts/fixtures/med_09_fromilid.json` (test în `ShareDemoTests`).
    static func prescription(bundle: Bundle = .main) throws -> MedicationItem {
        guard let url = bundle.url(forResource: "med_09_fromilid", withExtension: "json") else {
            throw Failure.missing
        }
        return try JSONCoding.decoder.decode(MedicationItem.self, from: Data(contentsOf: url))
    }
}
