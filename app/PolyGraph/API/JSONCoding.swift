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
