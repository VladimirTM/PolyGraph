import Foundation
import Testing
@testable import PolyGraph

/// T-A1-01: fiecare fișier din contracts/examples/ și contracts/fixtures/ se decodează în modelul generat,
/// se encodează înapoi fără să piardă câmpuri, iar al doilea ciclu dă exact aceiași octeți.
///
/// Fișierele se citesc direct din repo (testele rulează pe simulator, care vede discul Mac-ului),
/// ca să nu fie nevoie de un folder reference în `project.pbxproj`.
@MainActor
struct ContractsCodingTests {
    @Test(arguments: ContractFiles.examples)
    func example(_ name: String) throws {
        let data = try ContractFiles.data("examples/\(name)")
        let prefix = String(name.prefix { $0 != "." })
        switch prefix {
        case "alert": try roundTrip(Alert.self, data)
        case "analysis": try roundTrip(Analysis.self, data)
        case "checkin": try roundTrip(CheckIn.self, data)
        case "dose": try roundTrip(Dose.self, data)
        case "extraction": try roundTrip(ExtractionResult.self, data)
        case "feed_event": try roundTrip(FeedEvent.self, data)
        case "graph": try roundTrip(Graph.self, data)
        case "kb_search_result": try roundTrip(KBSearchResult.self, data)
        case "medication_item": try roundTrip(MedicationItem.self, data)
        case "patient": try roundTrip(Patient.self, data)
        case "patient_create": try roundTrip(PatientCreate.self, data)
        case "patient_created": try roundTrip(PatientCreated.self, data)
        case "schedule": try roundTrip(Schedule.self, data)
        case "share_link": try roundTrip(ShareLink.self, data)
        case "what_if_request": try roundTrip(WhatIfRequest.self, data)
        case "what_if_result": try roundTrip(WhatIfResult.self, data)
        default:
            Issue.record("Exemplu fără model în test: \(name). Adaugă-l în switch.")
        }
    }

    @Test(arguments: ContractFiles.fixtures)
    func fixture(_ name: String) throws {
        let data = try ContractFiles.data("fixtures/\(name)")
        switch name {
        case "demo_patient.json": try roundTrip(DemoPatientFixture.self, data)
        case "med_09_fromilid.json": try roundTrip(MedicationItem.self, data)
        case "expected_alerts.json": try roundTrip(ExpectedAlertsFixture.self, data)
        case "expected_schedule.json": try roundTrip(Schedule.self, data)
        case "checkin_demo.json": try roundTrip(CheckIn.self, data)
        case "gs1_cases.json": try roundTrip(GS1CasesFixture.self, data)
        case "date_words.json": try roundTrip(DateWordsFixture.self, data)
        default:
            Issue.record("Fixture fără model în test: \(name). Adaugă-l în switch.")
        }
    }

    @Test func contractFilesAreFound() {
        #expect(ContractFiles.examples.count >= 10, "Nu găsesc contracts/examples la \(ContractFiles.root.path())")
        #expect(ContractFiles.fixtures.count >= 6, "Nu găsesc contracts/fixtures la \(ContractFiles.root.path())")
    }

    @Test func demoPatientHasEightMeds() throws {
        let fixture = try JSONCoding.decoder.decode(
            DemoPatientFixture.self, from: ContractFiles.data("fixtures/demo_patient.json"))
        #expect(fixture.meds.count == 8)
    }

    @Test func unknownEnumValueFailsToDecode() throws {
        var object = try #require(
            try JSONSerialization.jsonObject(with: ContractFiles.data("examples/alert.food.json")) as? [String: Any])
        object["kind"] = "astrology"
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            try JSONCoding.decoder.decode(Alert.self, from: data)
        }
    }

    @Test func fractionalSecondsDecode() throws {
        let json = #"{"med_id":"med_01","scheduled_at":"2026-11-14T07:00:00+02:00","status":"taken","recorded_at":"2026-11-14T05:01:12.345678Z"}"#
        let dose = try JSONCoding.decoder.decode(Dose.self, from: Data(json.utf8))
        #expect(dose.recordedAt != nil)
        #expect(dose.scheduledAt == JSONCoding.parseISO8601("2026-11-14T05:00:00Z"))
    }

    // MARK: - Ajutătoare

    private func roundTrip<T: Codable>(_ type: T.Type, _ data: Data) throws {
        let decoded = try JSONCoding.decoder.decode(T.self, from: data)
        let encoded = try JSONCoding.encoder.encode(decoded)
        let again = try JSONCoding.decoder.decode(T.self, from: encoded)
        #expect(try JSONCoding.encoder.encode(again) == encoded)

        let original = try JSONSerialization.jsonObject(with: data)
        let reencoded = try JSONSerialization.jsonObject(with: encoded)
        let lost = ContractFiles.lostKeys(original, reencoded)
        #expect(lost.isEmpty, "Câmpuri pierdute la encodare: \(lost)")
    }
}

// MARK: - Învelișurile fixture-urilor (nu sunt tipuri de contract, doar fișiere de test)

@MainActor
private struct DemoPatientFixture: Codable {
    let today: String
    let patient: Patient
    let meds: [MedicationItem]
}

@MainActor
private struct ExpectedAlertsFixture: Codable {
    let today: String
    let compareOn: [String]
    let withoutMed09: [Alert]
    let addedWithMed09: [Alert]

    enum CodingKeys: String, CodingKey {
        case today
        case compareOn = "compare_on"
        case withoutMed09 = "without_med_09"
        case addedWithMed09 = "added_with_med_09"
    }
}

@MainActor
private struct GS1CasesFixture: Codable {
    struct Case: Codable {
        struct Expected: Codable {
            let gtin: String
            let expiry: String?
            let batch: String?
            let serial: String?
        }

        let name: String
        let raw: String
        let expected: Expected?
        let note: String?
        let synthetic: Bool
        let medID: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case name, raw, expected, note, synthetic, error
            case medID = "med_id"
        }
    }

    let description: String
    let cases: [Case]
}

@MainActor
private struct DateWordsFixture: Codable {
    struct Case: Codable {
        let at: String
        let text: String
    }

    let now: String
    let timezone: String
    let cases: [Case]
}

// MARK: - Fișierele din contracts/

enum ContractFiles {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // PolyGraphTests/
        .deletingLastPathComponent()  // app/
        .deletingLastPathComponent()  // rădăcina repo-ului
        .appending(path: "contracts")

    static let examples = jsonFiles(in: "examples")
    static let fixtures = jsonFiles(in: "fixtures")

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: root.appending(path: relativePath))
    }

    private static func jsonFiles(in folder: String) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.appending(path: folder).path())) ?? []
        return names.filter { $0.hasSuffix(".json") }.sorted()
    }

    /// Cheile cu valoare ne-nulă din original care lipsesc după encodare (null-urile se omit, e normal).
    static func lostKeys(_ original: Any, _ encoded: Any, path: String = "$") -> [String] {
        if let original = original as? [String: Any] {
            guard let encoded = encoded as? [String: Any] else { return [path] }
            return original.flatMap { key, value -> [String] in
                if value is NSNull { return [] }
                guard let other = encoded[key] else { return ["\(path).\(key)"] }
                return lostKeys(value, other, path: "\(path).\(key)")
            }
        }
        if let original = original as? [Any] {
            guard let encoded = encoded as? [Any], encoded.count == original.count else { return [path] }
            return zip(original, encoded).enumerated().flatMap { index, pair in
                lostKeys(pair.0, pair.1, path: "\(path)[\(index)]")
            }
        }
        return []
    }
}
