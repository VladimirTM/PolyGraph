import Foundation

/// Encoder-ul și decoder-ul pentru API. Datele vin ca ISO 8601, uneori cu fracțiuni de secundă
/// (FastAPI le pune), lucru pe care strategia `.iso8601` din Foundation nu-l acceptă.
enum JSONCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { try JSONCoding.decodeDate($0) }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    nonisolated static func decodeDate(_ decoder: any Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = parseISO8601(text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Dată ISO 8601 invalidă: \(text)")
        }
        return date
    }

    nonisolated static func parseISO8601(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    /// Cu fracțiuni, ca `since` din /feed să nu reîntoarcă evenimentul din aceeași secundă.
    nonisolated static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

// MARK: - Câmpurile null cerute de schemă

extension JSONCoding {
    /// Corpul pentru `POST /meds`. Encoderul sintetizat omite câmpurile `nil`, dar
    /// `medication_item.schema.json` le cere prezente (cu `null`), iar backend-ul real validează schema
    /// și răspunde 422 (o rețetă fără cod pe cutie n-are `gtin`, `batch`, `expiry`).
    static func medicationBody(_ med: MedicationItem) throws -> Data {
        let data = try encoder.encode(med)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        fillNulls(&object, ["start_date", "end_date", "photo_url"])
        fillNulls(&object, in: "product", ["strength_text", "form", "gtin", "pack_size", "expiry", "batch"])
        fillNulls(&object, in: "dosage", ["raw"])
        fillNulls(&object, in: "prescriber", ["name", "specialty"])
        if var substances = object["substances"] as? [[String: Any]] {
            for index in substances.indices {
                fillNulls(&substances[index], ["dci", "inn", "atc", "strength_mg"])
            }
            object["substances"] = substances
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func fillNulls(_ object: inout [String: Any], _ keys: [String]) {
        for key in keys where object[key] == nil {
            object[key] = NSNull()
        }
    }

    private static func fillNulls(_ object: inout [String: Any], in parent: String, _ keys: [String]) {
        guard var child = object[parent] as? [String: Any] else { return }
        fillNulls(&child, keys)
        object[parent] = child
    }
}
