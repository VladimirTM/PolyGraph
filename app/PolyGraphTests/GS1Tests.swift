import Foundation
import Testing
@testable import PolyGraph

/// T-A2-01: aceleași cazuri ca parserul Python (T-B3-04), din `contracts/fixtures/gs1_cases.json`.
@MainActor
struct GS1Tests {
    @Test func fixtureIsFound() {
        #expect(GS1Fixture.cases.count >= 12, "Nu găsesc cazurile din contracts/fixtures/gs1_cases.json")
    }

    @Test(arguments: GS1Fixture.cases)
    func matchesFixture(_ testCase: GS1Fixture.Case) throws {
        if let expected = testCase.expected {
            let parsed = try GS1.parse(testCase.raw)
            #expect(parsed == GS1Data(
                gtin: expected.gtin, expiry: expected.expiry, batch: expected.batch, serial: expected.serial))
        } else {
            let code = try #require(testCase.error, "Cazul \(testCase.name) nu are nici expected, nici error")
            let error = try #require(GS1Error(rawValue: code), "Cod de eroare necunoscut: \(code)")
            #expect(throws: error) { try GS1.parse(testCase.raw) }
        }
    }

    @Test func toleratesTrailingNewlineFromScanner() throws {
        let parsed = try GS1.parse("]d20105949000000014\r\n")
        #expect(parsed.gtin == "05949000000014")
    }

    @Test func unknownApplicationIdentifierIsNotGS1() {
        #expect(throws: GS1Error.notGS1) { try GS1.parse("0105949000000014" + "99XYZ") }
    }

    @Test func monthThirteenIsInvalidExpiry() {
        #expect(throws: GS1Error.invalidExpiry) { try GS1.parse("010594900000001417281301") }
    }
}

nonisolated enum GS1Fixture {
    struct Case: Decodable, Sendable, CustomTestStringConvertible {
        struct Expected: Decodable, Sendable {
            let gtin: String
            let expiry: String?
            let batch: String?
            let serial: String?
        }

        let name: String
        let raw: String
        let expected: Expected?
        let error: String?

        var testDescription: String { name }
    }

    private struct File: Decodable {
        let cases: [Case]
    }

    static let cases: [Case] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "contracts/fixtures/gs1_cases.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode(File.self, from: data).cases) ?? []
    }()
}
