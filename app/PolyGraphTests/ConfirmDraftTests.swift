import Foundation
import Testing
@testable import PolyGraph

/// T-A2-02: din `ExtractionResult`-ul fixture, modelul de confirmare marchează exact câmpurile nesigure,
/// iar „Salvează” produce `MedicationItem`-ul editat.
@MainActor
struct ConfirmDraftTests {
    private func sintrom() throws -> MedicationItem {
        let result = try JSONCoding.decoder.decode(
            ExtractionResult.self, from: ContractFiles.data("examples/extraction.box_sintrom.json"))
        return try #require(result.candidates.first)
    }

    @Test func confidentMatchMarksNothing() throws {
        let draft = MedDraft(try sintrom())
        #expect(draft.reviewFields.isEmpty)
        #expect(!draft.hasEdits)
    }

    @Test func missingATCMarksOnlySubstances() throws {
        let item = try sintrom()
        let uncertain = item.with(
            match: item.match.with(needsReview: true),
            substances: item.substances.map { $0.with(atc: .some(nil)) })
        #expect(MedDraft(uncertain).reviewFields == [.substances])
    }

    @Test func lowConfidenceMarksProduct() throws {
        let item = try sintrom()
        let uncertain = item.with(match: item.match.with(confidence: 0.6, method: .fuzzy, needsReview: true))
        #expect(MedDraft(uncertain).reviewFields == [.product])
    }

    @Test func boxWithoutPosologyAlwaysMarksDosage() throws {
        let item = try sintrom()
        let empty = item.with(dosage: item.dosage.with(pattern: Pattern(bedtime: 0, evening: 0, morning: 0, noon: 0)))
        #expect(MedDraft(empty).reviewFields == [.dosage])
    }

    @Test func blankManualItemNeedsEverything() {
        let fields = MedDraft(MedDraft.blankItem()).reviewFields
        #expect(fields == [.product, .substances, .dosage])
    }

    @Test func saveProducesTheEditedItem() throws {
        let original = try sintrom()
        let draft = MedDraft(original)
        draft.evening = 1
        draft.morning = 0.5
        draft.withFood = .withMeal
        draft.prescriberName = "Dr. Pop"
        draft.expiry = MedDraft.date(fromISODay: "2029-01-31")
        #expect(draft.hasEdits)

        let saved = draft.item()
        #expect(saved.id == original.id)
        #expect(saved.dosage.pattern.evening == 1)
        #expect(saved.dosage.pattern.morning == 0.5)
        #expect(saved.dosage.pattern.noon == 0)
        #expect(saved.dosage.withFood == .withMeal)
        #expect(saved.dosage.raw == original.dosage.raw)
        #expect(saved.prescriber.name == "Dr. Pop")
        #expect(saved.prescriber.specialty == original.prescriber.specialty)
        #expect(saved.product.expiry == "2029-01-31")
        #expect(saved.product.gtin == original.product.gtin)
        #expect(saved.product.batch == original.product.batch)
        #expect(saved.product.brand == "Sintrom")
        #expect(saved.match.method == original.match.method)
        #expect(!saved.match.needsReview)
    }

    @Test func untouchedDraftKeepsTheCandidate() throws {
        let original = try sintrom()
        let saved = MedDraft(original).item()
        let a = try JSONCoding.encoder.encode(saved)
        let b = try JSONCoding.encoder.encode(original)
        #expect(a == b)
    }

    @Test func catalogPickReplacesIdentification() throws {
        let draft = MedDraft(MedDraft.blankItem())
        let hits = try JSONCoding.decoder.decode(
            KBSearchResult.self, from: ContractFiles.data("examples/kb_search_result.sint.json"))
        let hit = try #require(hits.results.first)
        draft.apply(hit)

        let saved = draft.item()
        #expect(saved.product.brand == hit.brand)
        #expect(saved.substances.count == hit.substances.count)
        #expect(saved.match.method == .manual)
        #expect(saved.match.confidence == 1)
        #expect(!saved.match.needsReview)
        #expect(saved.source == .manual)
    }

    @Test func emptyNameCannotBeSaved() {
        let draft = MedDraft(MedDraft.blankItem())
        #expect(!draft.canSave)
        draft.brand = "Sintrom"
        #expect(draft.canSave)
    }

    // Q3-28: „9999 mg” la Sintrom 4 mg primește avertizarea; „2 mg” nu
    @Test func unusualStrengthIsFlagged() throws {
        let draft = MedDraft(try sintrom())
        #expect(!draft.strengthLooksUnusual)
        draft.strengthText = "9999 mg"
        #expect(draft.strengthLooksUnusual)
        draft.strengthText = "2 mg"
        #expect(!draft.strengthLooksUnusual)
    }

    @Test func expiryComparesByDay() throws {
        let draft = MedDraft(try sintrom())
        draft.expiry = MedDraft.date(fromISODay: "2024-01-31")
        #expect(draft.isExpired(on: try #require(MedDraft.date(fromISODay: "2024-02-01"))))
        #expect(!draft.isExpired(on: try #require(MedDraft.date(fromISODay: "2024-01-31"))))
    }

    @Test func blankItemCarriesTheScannedCode() throws {
        let code = try GS1.parse("]d2010594900000001417280331\u{1D}10AB123")
        let item = MedDraft.blankItem(code: code)
        #expect(item.product.gtin == "05949000000014")
        #expect(item.product.expiry == "2028-03-31")
        #expect(item.source == .datamatrix)
        #expect(item.id.hasPrefix("med_"))
    }

    @Test func halfPillsAreWrittenAsFractions() {
        #expect(PgFormat.doseAmount(0) == "0")
        #expect(PgFormat.doseAmount(0.5) == "½")
        #expect(PgFormat.doseAmount(1) == "1")
        #expect(PgFormat.doseAmount(1.5) == "1 ½")
    }
}

@MainActor
struct ScanCompletionTests {
    @Test func completionMessageNamesNewAlerts() {
        #expect(MedsListView.completionText(ScanOutcome(savedCount: 1, newAlerts: NewAlerts(grave: 2)))
            == "Am salvat. 2 alerte grave noi")
        #expect(MedsListView.completionText(ScanOutcome(savedCount: 1, newAlerts: NewAlerts()))
            == "Am salvat. Nicio alertă gravă nouă")
        #expect(MedsListView.completionText(ScanOutcome(savedCount: 3, newAlerts: NewAlerts(grave: 1)))
            == "Am salvat 3 medicamente. O alertă gravă nouă")
    }
}

@MainActor
struct DuplicateTests {
    private func sintrom() throws -> MedicationItem {
        let result = try JSONCoding.decoder.decode(
            ExtractionResult.self, from: ContractFiles.data("examples/extraction.box_sintrom.json"))
        return try #require(result.candidates.first)
    }

    @Test func sameNameAndStrengthIsDuplicate() throws {
        let existing = try sintrom().with(id: "med_old", product: try sintrom().product.with(gtin: .some(nil)))
        let draft = MedDraft(try sintrom().with(product: try sintrom().product.with(gtin: .some(nil))))
        #expect(draft.duplicate(in: [existing])?.id == "med_old")
    }

    @Test func sameGTINIsDuplicateEvenWithOtherName() throws {
        let existing = try sintrom().with(id: "med_old", product: try sintrom().product.with(brand: "Altceva"))
        #expect(MedDraft(try sintrom()).duplicate(in: [existing])?.id == "med_old")
    }

    @Test func otherStrengthIsNotDuplicate() throws {
        let item = try sintrom()
        let existing = item.with(id: "med_old", product: item.product.with(gtin: .some(nil), strengthText: .some("2 mg")))
        let draft = MedDraft(item.with(product: item.product.with(gtin: .some(nil))))
        #expect(draft.duplicate(in: [existing]) == nil)
    }

    @Test func sameIDFromScanIsStillDuplicate() throws {
        let item = try sintrom()
        #expect(MedDraft(item).duplicate(in: [item])?.id == item.id)
    }

    @Test func editedMedIsNotItsOwnDuplicate() throws {
        let item = try sintrom()
        #expect(MedDraft(item).duplicate(in: [item], excluding: item.id) == nil)
    }

    @Test func scannedCodeOverridesServerExpiry() throws {
        let result = try JSONCoding.decoder.decode(
            ExtractionResult.self, from: ContractFiles.data("examples/extraction.box_sintrom.json"))
        let fixed = ScanModel.withScannedCode(
            result, kind: .box, datamatrix: "010594900000001417240131\u{1D}10OLD1")
        let product = try #require(fixed.candidates.first).product
        #expect(product.expiry == "2024-01-31")
        #expect(product.batch == "OLD1")
        #expect(product.gtin == "05949000000014")
    }

    @Test func prescriptionIgnoresCode() throws {
        let result = try JSONCoding.decoder.decode(
            ExtractionResult.self, from: ContractFiles.data("examples/extraction.box_sintrom.json"))
        let same = ScanModel.withScannedCode(
            result, kind: .prescription, datamatrix: "010594900000001417240131\u{1D}10OLD1")
        #expect(same.candidates.first?.product.expiry == "2028-03-31")
    }
}
