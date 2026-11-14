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

    /// „Azi, 14:00” / „Ieri, 20:00” / „joi, 12 nov., 14:00” (anul doar când nu e cel curent), ca în portal
    /// (`share/view.py` `relative_day`); perechile comune sunt în contracts/fixtures/date_words.json (Q3-13).
    /// Numele zilelor și lunilor sunt scrise aici, nu luate din `Locale`, ca să iasă identic cu portalul.
    static func relativeDay(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        let clock = String(format: "%02ld:%02ld", parts.hour ?? 0, parts.minute ?? 0)
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case 0: return "Azi, \(clock)"
        case 1: return "Ieri, \(clock)"
        default:
            // `weekday` din Calendar: 1 = duminică
            let weekday = weekdays[((parts.weekday ?? 1) + 5) % 7]
            let month = shortMonths[max(0, min(11, (parts.month ?? 1) - 1))]
            let year = parts.year != calendar.component(.year, from: now) ? " \(parts.year ?? 0)" : ""
            return "\(weekday), \(parts.day ?? 0) \(month)\(year), \(clock)"
        }
    }

    /// luni = 0, ca `date.weekday()` din Python
    static let weekdays = ["luni", "marți", "miercuri", "joi", "vineri", "sâmbătă", "duminică"]
    static let shortMonths = ["ian.", "feb.", "mar.", "apr.", "mai", "iun.", "iul.", "aug.", "sept.", "oct.", "nov.", "dec."]

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
