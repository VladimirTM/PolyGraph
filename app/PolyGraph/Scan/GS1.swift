import Foundation

/// Conținutul unui cod GS1 DataMatrix de pe cutie: AI 01 (GTIN), 17 (expirare), 10 (lot), 21 (serie).
nonisolated struct GS1Data: Equatable, Sendable {
    var gtin: String
    /// `yyyy-MM-dd`; ziua 00 de pe cutie devine ultima zi a lunii
    var expiry: String?
    var batch: String?
    var serial: String?
}

/// Codurile de eroare sunt aceleași ca în `backend/polygraph/extract/gs1.py` (câmpul `error` din fixture).
nonisolated enum GS1Error: String, Error, Equatable, Sendable {
    case notGS1 = "not_gs1"
    case invalidGTINCheckDigit = "invalid_gtin_check_digit"
    case invalidExpiry = "invalid_expiry"
}

/// Același parser ca în Python (B3), cu aceleași cazuri: `contracts/fixtures/gs1_cases.json`.
/// Orice schimbare de comportament se face în ambele locuri.
nonisolated enum GS1 {
    static let groupSeparator: Character = "\u{1D}"
    private static let symbologyPrefix = "]d2"

    static func parse(_ raw: String) throws -> GS1Data {
        var text = Substring(raw.trimmingCharacters(in: CharacterSet(charactersIn: " \r\n")))
        if text.hasPrefix(symbologyPrefix) { text = text.dropFirst(symbologyPrefix.count) }
        let chars = Array(text)

        var gtin: String?
        var expiry: String?
        var batch: String?
        var serial: String?
        var i = 0

        while i < chars.count {
            while i < chars.count, chars[i] == groupSeparator { i += 1 }
            guard i < chars.count else { break }
            guard i + 2 <= chars.count else { throw GS1Error.notGS1 }
            let ai = String(chars[i..<(i + 2)])
            i += 2

            switch ai {
            case "01", "17":
                let length = ai == "01" ? 14 : 6
                let end = min(i + length, chars.count)
                let value = String(chars[i..<end])
                i = end
                if ai == "01" {
                    guard gtin == nil else { throw GS1Error.notGS1 }
                    guard value.count == length, value.allSatisfy(isDigit) else { throw GS1Error.notGS1 }
                    guard isValidGTIN(value) else { throw GS1Error.invalidGTINCheckDigit }
                    gtin = value
                } else {
                    guard expiry == nil else { throw GS1Error.notGS1 }
                    guard value.count == length, value.allSatisfy(isDigit) else { throw GS1Error.notGS1 }
                    expiry = try expiryDate(value)
                }
            case "10", "21":
                guard (ai == "10" ? batch : serial) == nil else { throw GS1Error.notGS1 }
                // lungime variabilă: până la GS sau la sfârșit
                var end = i
                while end < chars.count, chars[end] != groupSeparator { end += 1 }
                let value = String(chars[i..<end])
                i = min(end + 1, chars.count)
                guard (1...20).contains(value.count), value.allSatisfy(isPrintableASCII) else {
                    throw GS1Error.notGS1
                }
                if ai == "10" { batch = value } else { serial = value }
            default:
                throw GS1Error.notGS1
            }
        }

        guard let gtin else { throw GS1Error.notGS1 }
        return GS1Data(gtin: gtin, expiry: expiry, batch: batch, serial: serial)
    }

    /// Cifra de control GS1 (mod 10, ponderi 1 și 3 de la dreapta).
    static func isValidGTIN(_ value: String) -> Bool {
        guard value.count == 14, value.allSatisfy(isDigit) else { return false }
        let sum = value.reversed().enumerated().reduce(0) { total, pair in
            total + Int(String(pair.element))! * (pair.offset % 2 == 0 ? 1 : 3)
        }
        return sum % 10 == 0
    }

    /// `AALLZZ` → `yyyy-MM-dd`.
    private static func expiryDate(_ value: String) throws -> String {
        let digits = value.compactMap { Int(String($0)) }
        let year = 2000 + digits[0] * 10 + digits[1]
        let month = digits[2] * 10 + digits[3]
        let day = digits[4] * 10 + digits[5]
        guard (1...12).contains(month) else { throw GS1Error.invalidExpiry }
        let lastDay = daysIn(month: month, year: year)
        guard day <= lastDay else { throw GS1Error.invalidExpiry }
        return String(format: "%04ld-%02ld-%02ld", year, month, day == 0 ? lastDay : day)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    private static func isDigit(_ c: Character) -> Bool {
        c.isASCII && c.isNumber
    }

    private static func isPrintableASCII(_ c: Character) -> Bool {
        guard let value = c.asciiValue else { return false }
        return (33...126).contains(value)
    }
}
