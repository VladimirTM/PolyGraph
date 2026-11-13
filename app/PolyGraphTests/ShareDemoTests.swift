import Foundation
import Testing
import UIKit
@testable import PolyGraph

@MainActor
struct ShareTests {
    private func date(day: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func expiryLaterThisWeekNamesTheWeekday() {
        // vineri 13 noiembrie, 22:30 + 72 h = luni 16 noiembrie, 22:30
        let now = date(day: 13, hour: 22, minute: 30)
        #expect(PgFormat.validUntil(date(day: 16, hour: 22, minute: 30), now: now) == "Valabil până luni, 22:30")
    }

    @Test func expiryTomorrowAndToday() {
        let now = date(day: 13, hour: 9, minute: 0)
        #expect(PgFormat.validUntil(date(day: 14, hour: 9, minute: 30), now: now) == "Valabil până mâine, 09:30")
        #expect(PgFormat.validUntil(date(day: 13, hour: 18, minute: 0), now: now) == "Valabil până azi, 18:00")
    }

    @Test func qrCodeIsGeneratedForTheShareLink() throws {
        let image = try #require(QRCode.image(for: "http://192.168.1.10:8000/share/AbC123_xyz-0987654321"))
        // cel mai mic QR are 21 de module pe latură
        #expect(image.size.width >= 21)
        #expect(image.size.width == image.size.height)
    }
}

@MainActor
struct DemoDataTests {
    private static let appFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // PolyGraphTests/
        .deletingLastPathComponent()  // app/

    @Test func bundledPrescriptionMatchesTheContractFixture() throws {
        let bundled = Self.appFolder.appending(path: "PolyGraph/Resources/med_09_fromilid.json")
        #expect(try Data(contentsOf: bundled) == ContractFiles.data("fixtures/med_09_fromilid.json"))
        let med = try JSONCoding.decoder.decode(MedicationItem.self, from: Data(contentsOf: bundled))
        #expect(med.product.brand == "Fromilid")
    }

    // T-A6-01: animațiile și culorile vin doar din Design/
    @Test func noHandWrittenMotionOrColorOutsideDesign() throws {
        let sources = Self.appFolder.appending(path: "PolyGraph")
        let files = (FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? [])
            .filter { $0.pathExtension == "swift" && !$0.path.contains("/PolyGraph/Design/") }
        #expect(files.count > 20, "Nu găsesc sursele la \(sources.path)")

        let forbidden = [".spring(", "Color(red:", "Animation.easeInOut(", ".animation(.easeInOut"]
        var hits: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for pattern in forbidden where text.contains(pattern) {
                hits.append("\(file.lastPathComponent): \(pattern)")
            }
        }
        #expect(hits.isEmpty, "Valori scrise de mână în afara Design/: \(hits)")
    }
}
