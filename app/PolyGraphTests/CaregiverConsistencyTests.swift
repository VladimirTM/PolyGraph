import Foundation
import Testing
@testable import PolyGraph

/// Q3F4: aparținătorul vede date, numere și culori identice cu cele din portalul medicului.
@MainActor
struct CaregiverConsistencyTests {
    @MainActor
    private struct DateWords: Decodable {
        struct Case: Decodable {
            let at: Date
            let text: String
        }

        let now: Date
        let timezone: String
        let cases: [Case]
    }

    @MainActor
    private struct ExpectedAlerts: Decodable {
        let withoutMed09: [Alert]
        let addedWithMed09: [Alert]

        enum CodingKeys: String, CodingKey {
            case withoutMed09 = "without_med_09"
            case addedWithMed09 = "added_with_med_09"
        }
    }

    private func expectedAlerts() throws -> ExpectedAlerts {
        try JSONCoding.decoder.decode(ExpectedAlerts.self, from: ContractFiles.data("fixtures/expected_alerts.json"))
    }

    // T-Q3F4-01: aceleași perechi le verifică și pytest pe `share/view.py` (backend/tests/test_q3f4.py)
    @Test func dateWordsMatchThePortal() throws {
        let fixture = try JSONCoding.decoder.decode(
            DateWords.self, from: ContractFiles.data("fixtures/date_words.json"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: fixture.timezone))
        #expect(fixture.cases.count >= 5)
        for item in fixture.cases {
            #expect(PgFormat.relativeDay(item.at, now: fixture.now, calendar: calendar) == item.text)
        }
    }

    // Q3-27: „Am adăugat Fromilid. 2 alerte grave noi și 2 de discutat.” = cele 2 grave din rezumatul portalului
    @Test func fromilidCountsOnlyWhatTheCaregiverSees() throws {
        let alerts = try expectedAlerts()
        let added = NewAlerts(before: alerts.withoutMed09, after: alerts.withoutMed09 + alerts.addedWithMed09)
        #expect(added == NewAlerts(grave: 2, discuss: 2))
        #expect(SettingsView.prescriptionText(added) == "Am adăugat Fromilid. 2 alerte grave noi și 2 de discutat.")
    }

    @Test func newAlertsWording() {
        #expect(NewAlerts(grave: 1).sentence == "O alertă gravă nouă")
        #expect(NewAlerts(grave: 2).text == "2 alerte grave noi")
        #expect(NewAlerts(grave: 1, discuss: 1).text == "o alertă gravă nouă și una de discutat")
        #expect(NewAlerts(discuss: 3).text == "3 alerte noi de discutat")
        #expect(NewAlerts(discuss: 1).text == "o alertă nouă de discutat")
        #expect(NewAlerts(grave: 20).text == "20 de alerte grave noi")
        #expect(NewAlerts().sentence == "Nicio alertă gravă nouă")
        #expect(NewAlerts(grave: 1) + NewAlerts(grave: 1, discuss: 2) == NewAlerts(grave: 2, discuss: 2))
    }

    @Test func completionTextUsesTheSameCount() {
        #expect(MedsListView.completionText(ScanOutcome(savedCount: 1, newAlerts: NewAlerts(grave: 2)))
            == "Am salvat. 2 alerte grave noi")
        #expect(MedsListView.completionText(ScanOutcome(savedCount: 3, newAlerts: NewAlerts(grave: 1, discuss: 2)))
            == "Am salvat 3 medicamente. O alertă gravă nouă și 2 de discutat")
    }

    // T-Q3F4-04: ACB după severitatea alertei lui (moderate în fixture → portocaliu), nu roșu
    @Test func acbColorFollowsItsAlert() throws {
        #expect(AcbCard.severity(of: try expectedAlerts().withoutMed09) == .moderate)
        #expect(AcbCard.severity(of: []) == .moderate)
    }

    // Q3-24: un lot mare dă o singură notificare
    @Test func bigBatchGivesOneNotification() {
        final class Recorder {
            var single: [String] = []
            var batches: [(Int, Int)] = []
        }
        let recorder = Recorder()
        let feed = FeedModel(
            notify: { recorder.single.append($0.id) },
            notifyBatch: { recorder.batches.append(($0, $1)) })
        feed.receive([])
        let many = (1...5).map { minute in
            FeedEvent(
                alertid: nil, at: Date(timeIntervalSince1970: 1_794_600_000 + Double(minute * 60)), body: "corp",
                checkinid: minute <= 2 ? "ci_\(minute)" : nil, id: "ev_\(minute)", medids: [], severity: nil,
                title: "Maria a raportat: amețeală", type: minute <= 2 ? .checkin : .doseMissed)
        }
        feed.receive(many)
        #expect(recorder.single.isEmpty)
        #expect(recorder.batches.count == 1)
        #expect(recorder.batches.first?.0 == 5 && recorder.batches.first?.1 == 2)
        #expect(FeedAlerts.summary(patient: "Maria", total: 5, serious: 2) == "Maria: 5 noutăți, 2 grave")
        #expect(FeedAlerts.summary(patient: "Maria", total: 32, serious: 32) == "Maria: 32 de noutăți, 32 grave")
    }
}
