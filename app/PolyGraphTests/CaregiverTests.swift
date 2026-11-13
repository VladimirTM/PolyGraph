import Foundation
import Testing
@testable import PolyGraph

/// T-A3-01: sortarea alertelor și gruparea pe specialitate, pe fixture-ul demo.
@MainActor
struct AlertSectionsTests {
    @MainActor
    private struct ExpectedAlerts: Decodable {
        let withoutMed09: [Alert]

        enum CodingKeys: String, CodingKey {
            case withoutMed09 = "without_med_09"
        }
    }

    @MainActor
    private struct DemoPatient: Decodable {
        let meds: [MedicationItem]
    }

    private func demoAlerts() throws -> [Alert] {
        try JSONCoding.decoder.decode(ExpectedAlerts.self, from: ContractFiles.data("fixtures/expected_alerts.json"))
            .withoutMed09
    }

    private func demoMeds() throws -> [MedicationItem] {
        try JSONCoding.decoder.decode(DemoPatient.self, from: ContractFiles.data("fixtures/demo_patient.json")).meds
    }

    // T-A3-01
    @Test func alertsAreSortedCriticalToMinorWhateverTheServerOrder() throws {
        let alerts = try demoAlerts()
        let sorted = Array(alerts.reversed()).sortedBySeverity()
        let ranks = sorted.map(\.severity.rank)
        #expect(ranks == ranks.sorted())
        #expect(sorted.first?.severity == .major)
        #expect(sorted.last?.severity == .minor)
    }

    @Test func sortingKeepsServerOrderWithinASeverity() throws {
        let alerts = try demoAlerts()
        let majors = alerts.filter { $0.severity == .major }.map(\.id)
        #expect(alerts.sortedBySeverity().filter { $0.severity == .major }.map(\.id) == majors)
    }

    // criteriul de acceptare A3: 4 carduri grave sus, fără alertele de mâncare și fără minore
    @Test func demoHasFourSeriousCardsOnTop() throws {
        let sections = AlertSections(try demoAlerts())
        #expect(sections.serious.map(\.id) == [
            "al_ddi_med_01_med_02",
            "al_ddi_med_03_med_04",
            "al_elderly_pim_med_02_beers-nsaid-chronic",
            "al_elderly_pim_med_08_beers-tricyclic-antidepressants",
        ])
        #expect(sections.moderate.count == 12)
        #expect(sections.food.count == 8)
        #expect(sections.food.first?.id == "al_food_med_03_grapefruit")
        #expect(sections.food.allSatisfy { $0.kind == .food })
        let shown = sections.serious + sections.moderate + sections.food
        #expect(!shown.contains { $0.severity == .minor })
        #expect(shown.count == 27 - 3)
    }

    @Test func moderateSummaryUsesRomanianPlurals() throws {
        let sections = AlertSections(try demoAlerts())
        #expect(sections.moderateSummary == "12 observații moderate, de discutat cu farmacistul la următoarea vizită")
        let onlyDDI = AlertSections(try demoAlerts().filter { $0.kind == .ddi && $0.severity == .moderate })
        #expect(onlyDDI.moderateSummary.hasPrefix("10 interacțiuni moderate"))
        let one = AlertSections(Array(try demoAlerts().filter { $0.kind == .ddi && $0.severity == .moderate }.prefix(1)))
        #expect(one.moderateSummary.hasPrefix("O interacțiune moderată"))
    }

    @Test func worstAlertForAMedIgnoresMinor() throws {
        let alerts = try demoAlerts()
        #expect(alerts.worst(forMed: "med_01")?.id == "al_ddi_med_01_med_02")
        #expect(alerts.worst(forMed: "med_05")?.severity == .moderate)
        #expect(alerts.worst(forMed: "med_99") == nil)
    }

    // T-A3-01
    @Test func demoMedsGroupIntoSixSpecialties() throws {
        let sections = MedSection.group(try demoMeds())
        #expect(sections.map(\.title) == [
            "Cardiologie",
            "Medicină de familie",
            "Endocrinologie",
            "Gastroenterologie",
            "Neurologie",
            "Fără rețetă",
        ])
        #expect(sections.flatMap(\.meds).count == 8)
        #expect(sections.first(where: { $0.title == "Medicină de familie" })?.meds.map(\.id) == ["med_03", "med_04", "med_06"])
        #expect(sections.last?.meds.map(\.id) == ["med_02"])
    }

    @Test func dosageReadsAsWords() throws {
        let meds = try demoMeds()
        #expect(PgFormat.dosageWords(meds[0].dosage) == "½ seara")
        #expect(PgFormat.dosageWords(meds[1].dosage) == "1 dimineața, 1 seara")
        let asNeeded = Dosage(
            asNeeded: true, pattern: Pattern(bedtime: 0, evening: 0, morning: 0, noon: 0), raw: nil, withFood: .any)
        #expect(PgFormat.dosageWords(asNeeded) == "La nevoie")
    }
}

/// T-A3-02: ștergerea cu „Anulează”.
@MainActor
struct DeleteUndoQueueTests {
    private final class Recorder {
        var deleted: [String] = []
    }

    // T-A3-02
    @Test func undoWithinTheWindowSendsNoDelete() async throws {
        let recorder = Recorder()
        let queue = DeleteUndoQueue(delay: .milliseconds(300)) { recorder.deleted.append($0) }

        queue.schedule(id: "med_01", name: "Sintrom 4 mg")
        #expect(queue.hiddenIDs == ["med_01"])
        #expect(queue.pending?.name == "Sintrom 4 mg")

        try await Task.sleep(for: .milliseconds(100))
        queue.undo()
        try await Task.sleep(for: .milliseconds(600))

        #expect(recorder.deleted.isEmpty)
        #expect(queue.hiddenIDs.isEmpty)
        #expect(queue.pending == nil)
    }

    @Test func withoutUndoTheDeleteIsSentOnceAfterTheWindow() async throws {
        let recorder = Recorder()
        let queue = DeleteUndoQueue(delay: .milliseconds(100)) { recorder.deleted.append($0) }

        queue.schedule(id: "med_01", name: "Sintrom 4 mg")
        #expect(recorder.deleted.isEmpty)
        try await Task.sleep(for: .milliseconds(500))

        #expect(recorder.deleted == ["med_01"])
        #expect(queue.pending == nil)
        #expect(queue.hiddenIDs.isEmpty)
    }

    @Test func aSecondDeleteCommitsTheFirst() async throws {
        let recorder = Recorder()
        let queue = DeleteUndoQueue(delay: .seconds(10)) { recorder.deleted.append($0) }

        queue.schedule(id: "med_01", name: "Sintrom 4 mg")
        queue.schedule(id: "med_02", name: "Nurofen 400 mg")
        try await Task.sleep(for: .milliseconds(200))

        #expect(recorder.deleted == ["med_01"])
        #expect(queue.pending?.id == "med_02")
        queue.undo()
        #expect(queue.hiddenIDs.isEmpty)
    }

    @Test func failedDeleteBringsTheMedBack() async throws {
        struct Offline: Error {}
        let queue = DeleteUndoQueue(delay: .milliseconds(50)) { _ in throw Offline() }

        queue.schedule(id: "med_01", name: "Sintrom 4 mg")
        try await Task.sleep(for: .milliseconds(400))

        #expect(queue.hiddenIDs.isEmpty)
        #expect(queue.lastError != nil)
    }

    @Test func theWindowIsFiveSeconds() {
        #expect(DeleteUndoQueue.undoWindow == .seconds(5))
    }
}
