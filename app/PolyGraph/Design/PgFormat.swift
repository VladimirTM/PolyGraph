import Foundation

/// Formatări fixe, independente de setările regionale ale telefonului (ora e mereu 24 h).
enum PgFormat {
    static let romanian = Locale(identifier: "ro_RO")

    /// „08:05”
    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02ld:%02ld", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// „2026-11-14”, ziua locală
    nonisolated static func isoDay(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// „vineri, 14 noiembrie”
    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(romanian))
    }

    /// „HH:MM” → data de azi la ora aceea (pentru DatePicker)
    static func date(fromClock text: String, on day: Date = Date()) -> Date? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    /// „Valabil până azi, 18:00”, „… mâine, 09:30”, „… luni, 22:30” (expirarea linkului pentru medic)
    static func validUntil(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)
        ).day ?? 0
        let day: String =
            switch days {
            case 0: "azi"
            case 1: "mâine"
            default: date.formatted(.dateTime.weekday(.wide).locale(romanian))
            }
        return "Valabil până \(day), \(clock(date))"
    }

    /// „un medicament”, „3 medicamente”, „20 de medicamente”
    static func medicationCount(_ count: Int) -> String {
        switch count {
        case 1: "un medicament"
        case 0, 2...19: "\(count) medicamente"
        default: "\(count) de medicamente"
        }
    }
}
