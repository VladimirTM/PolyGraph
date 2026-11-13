import Foundation
import Observation

/// Câmpurile pe care sheet-ul de confirmare le marchează cu „verificați”.
enum ReviewField: Hashable, CaseIterable {
    /// numele și concentrația (potrivirea în catalog)
    case product
    /// substanțele active (lipsă sau fără ATC)
    case substances
    /// când se ia
    case dosage
}

/// Un candidat de la /scan, editabil în sheet-ul de confirmare. `item()` dă `MedicationItem`-ul de salvat.
@Observable
final class MedDraft: Identifiable {
    let id: String
    let original: MedicationItem
    /// stabilite o singură dată, din răspunsul serverului; nu se schimbă pe măsură ce omul editează
    let reviewFields: Set<ReviewField>

    var brand: String
    var strengthText: String
    var form: String?
    var substances: [Substance]
    var morning: Double
    var noon: Double
    var evening: Double
    var bedtime: Double
    var asNeeded: Bool
    var withFood: WithFood
    var prescriberName: String
    var specialty: String
    var expiry: Date?
    private(set) var pickedFromCatalog = false

    @ObservationIgnored private var baseline: Data?

    init(_ item: MedicationItem) {
        id = item.id
        original = item
        reviewFields = Self.reviewFields(for: item)
        brand = item.product.brand
        strengthText = item.product.strengthText ?? ""
        form = item.product.form
        substances = item.substances
        morning = item.dosage.pattern.morning
        noon = item.dosage.pattern.noon
        evening = item.dosage.pattern.evening
        bedtime = item.dosage.pattern.bedtime
        asNeeded = item.dosage.asNeeded
        withFood = item.dosage.withFood
        prescriberName = item.prescriber.name ?? ""
        specialty = item.prescriber.specialty ?? ""
        expiry = item.product.expiry.flatMap(Self.date(fromISODay:))
        baseline = try? JSONCoding.encoder.encode(self.item())
    }

    // MARK: - Ce se marchează

    /// Doar când serverul a spus `needs_review`, se marchează câmpurile care au provocat-o (aceleași
    /// reguli ca în `backend/polygraph/extract/match.py`). Excepție: posologia goală se marchează mereu,
    /// pentru că o cutie nu spune niciodată cum se ia medicamentul.
    static func reviewFields(for item: MedicationItem) -> Set<ReviewField> {
        var fields: Set<ReviewField> = []
        let dosageMissing = item.dosage.pattern.total == 0 && !item.dosage.asNeeded
        if dosageMissing { fields.insert(.dosage) }
        guard item.match.needsReview else { return fields }
        let lowConfidence = item.match.confidence < 0.85
        let looseMethod = item.match.method == .fuzzy || item.match.method == .manual
        let missingName = item.product.brand.isEmpty || (item.product.strengthText ?? "").isEmpty
        if lowConfidence || looseMethod || missingName { fields.insert(.product) }
        if item.substances.isEmpty || item.substances.contains(where: { $0.atc == nil }) {
            fields.insert(.substances)
        }
        // needs_review fără o cauză vizibilă: identificarea e cea de verificat
        if fields.subtracting([.dosage]).isEmpty { fields.insert(.product) }
        return fields
    }

    func needsReview(_ field: ReviewField) -> Bool {
        reviewFields.contains(field)
    }

    // MARK: - Starea editării

    var hasEdits: Bool {
        (try? JSONCoding.encoder.encode(item())) != baseline
    }

    var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var displayName: String {
        let name = [brand, strengthText]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Medicament nou" : name
    }

    /// Opțiunile pentru masă din sheet; „după masă” apare doar dacă așa a venit de la server.
    var foodChoices: [WithFood] {
        let base: [WithFood] = [.emptyStomach, .beforeMeal, .withMeal, .any]
        return original.dosage.withFood == .afterMeal ? base + [.afterMeal] : base
    }

    func isExpired(on now: Date) -> Bool {
        guard let expiry else { return false }
        return PgFormat.isoDay(expiry) < PgFormat.isoDay(now)
    }

    /// Același medicament deja în listă: același GTIN sau același nume + concentrație (fără diacritice și majuscule).
    /// `excluding` = id-ul medicamentului editat (A3); la o scanare nouă, id-ul candidatului nu contează
    /// (mock-ul întoarce id-urile din fixture, deci pot coincide cu cele din listă).
    func duplicate(in meds: [MedicationItem], excluding excludedID: String? = nil) -> MedicationItem? {
        let gtin = original.product.gtin
        let key = Self.matchKey(brand, strengthText)
        return meds.first { med in
            if let excludedID, med.id == excludedID { return false }
            if let gtin, gtin == med.product.gtin { return true }
            return !key.isEmpty && key == Self.matchKey(med.product.brand, med.product.strengthText ?? "")
        }
    }

    private static func matchKey(_ brand: String, _ strength: String) -> String {
        let name = brand.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "" }
        return "\(name) \(strength)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    // MARK: - Concentrația și substanța

    /// Concentrația scrisă de mână nu mai e cea venită de la server sau din catalog.
    var strengthEdited: Bool {
        !pickedFromCatalog
            && Self.compact(strengthText) != Self.compact(original.product.strengthText ?? "")
    }

    /// Cu o singură substanță, concentrația nouă devine doza ei (`strength_mg`); ATC-ul rămâne același.
    var adjustedSubstances: [Substance] {
        guard strengthEdited, substances.count == 1, let mg = Self.milligrams(in: strengthText) else {
            return substances
        }
        return [substances[0].with(strengthMg: .some(mg))]
    }

    /// Cu mai multe substanțe (sau un text de nedescifrat), doza fiecăreia nu se poate deduce:
    /// omul e trimis în catalog, unde alege produsul cu concentrația corectă.
    var strengthNeedsCatalog: Bool {
        guard strengthEdited, !substances.isEmpty else { return false }
        return substances.count > 1 || Self.milligrams(in: strengthText) == nil
    }

    /// „4 mg” → 4, „75 mcg” → 0,075, „2,5 mg” → 2,5, „1 g” → 1000; altceva → nil.
    nonisolated static func milligrams(in text: String) -> Double? {
        let pattern = "(\\d+(?:[.,]\\d+)?)\\s*(mg|mcg|µg|μg|g)(?![a-z])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard matches.count == 1, let match = matches.first,
            let value = Double(ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "."))
        else { return nil }
        switch ns.substring(with: match.range(at: 2)).lowercased() {
        case "mg": return value
        case "g": return value * 1000
        default: return value / 1000
        }
    }

    private static func compact(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    /// Alegerea din /v1/kb/search înlocuiește identificarea (nume, concentrație, formă, substanțe).
    func apply(_ hit: KBSearchHit) {
        brand = hit.brand
        strengthText = hit.strengthText ?? ""
        form = hit.form
        substances = hit.substances
        pickedFromCatalog = true
    }

    // MARK: - Rezultatul

    /// „Salvează” înseamnă că omul a verificat: `needs_review` devine false.
    func item() -> MedicationItem {
        let product = original.product.with(
            brand: brand.trimmingCharacters(in: .whitespaces),
            expiry: .some(expiry.map(PgFormat.isoDay)),
            form: .some(form),
            strengthText: .some(Self.nonEmpty(strengthText)))
        let dosage = original.dosage.with(
            asNeeded: asNeeded,
            pattern: Pattern(bedtime: bedtime, evening: evening, morning: morning, noon: noon),
            withFood: withFood)
        let prescriber = Prescriber(name: Self.nonEmpty(prescriberName), specialty: Self.nonEmpty(specialty))
        let confirmedByHand = pickedFromCatalog || original.match.method == .manual
        let match = confirmedByHand
            ? Match(confidence: 1.0, method: .manual, needsReview: false)
            : original.match.with(needsReview: false)
        return original.with(
            dosage: dosage, match: match, prescriber: prescriber, product: product, substances: adjustedSubstances)
    }

    // MARK: - Ajutătoare

    /// Codul de pe cutie descrie exact cutia din mână: GTIN-ul, expirarea și lotul lui au prioritate
    /// față de ce a întors serverul (care poate da datele altei cutii din același produs).
    static func applying(_ code: GS1Data, to item: MedicationItem) -> MedicationItem {
        let product = item.product.with(
            batch: .some(code.batch ?? item.product.batch),
            expiry: .some(code.expiry ?? item.product.expiry),
            gtin: .some(code.gtin))
        return item.with(product: product)
    }

    static func blankItem(code: GS1Data? = nil) -> MedicationItem {
        MedicationItem(
            dosage: Dosage(
                asNeeded: false, pattern: Pattern(bedtime: 0, evening: 0, morning: 0, noon: 0), raw: nil, withFood: .any),
            endDate: nil,
            id: "med_" + String(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(12)),
            match: Match(confidence: 0, method: .manual, needsReview: true),
            photourl: nil,
            prescriber: Prescriber(name: nil, specialty: nil),
            product: Product(
                batch: code?.batch, brand: "", expiry: code?.expiry, form: nil, gtin: code?.gtin, packSize: nil,
                strengthText: nil),
            source: code == nil ? .manual : .datamatrix,
            startDate: nil,
            substances: [])
    }

    nonisolated static func date(fromISODay text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Pattern {
    var total: Double { morning + noon + evening + bedtime }
}

extension WithFood {
    /// Etichetele scurte din controlul segmentat.
    var shortLabel: String {
        switch self {
        case .emptyStomach: "Pe stomacul gol"
        case .beforeMeal: "Înainte"
        case .withMeal: "La masă"
        case .afterMeal: "După"
        case .any: "Oricând"
        }
    }
}

extension PgFormat {
    /// 0,5 → „½”, 1,5 → „1 ½”, 2 → „2”
    static func doseAmount(_ value: Double) -> String {
        let whole = Int(value)
        let half = value - Double(whole) >= 0.5
        switch (whole, half) {
        case (0, true): return "½"
        case (_, true): return "\(whole) ½"
        default: return "\(whole)"
        }
    }
}
