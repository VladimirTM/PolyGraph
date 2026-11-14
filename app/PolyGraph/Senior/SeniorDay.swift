import Foundation

/// Starea unui moment din program, după ce a apăsat pacientul.
enum MomentStatus: Equatable {
    /// nimic confirmat încă
    case open
    case taken
    case skipped
}

/// Ce arată „Acum” când nu mai e niciun moment de luat (Q3-04).
enum DayEnd: Equatable {
    /// programul n-are niciun moment (nu sunt medicamente)
    case empty
    /// toate momentele zilei au fost luate sau sărite
    case allDone
    /// au rămas momente neconfirmate, dar le-a trecut ora
    case nothingNow
}

/// Regulile modului senior, fără UI: ce moment e „acum”, ora unei doze, cuvintele pentru cantitate și voce.
enum SeniorDay {
    /// Cât rămâne „curent” un moment neconfirmat după ora lui.
    static let graceMinutes = 120
    /// Cu cât înainte de ora momentului apar butoanele „Am luat” / „Mai târziu” / „Am sărit”.
    static let earlyMinutes = 30
    static let snoozeMinutes = 15

    /// „07:30” → 450
    static func minutes(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Momentul curent (T-A4-01): primul moment neconfirmat a cărui oră a trecut de cel mult 2 h;
    /// altfel următorul moment neconfirmat; `nil` când nu mai e nimic de luat azi.
    static func currentMoment(in moments: [Moment], nowMinutes: Int, isDone: (Moment) -> Bool) -> Moment? {
        let open = moments.filter { !isDone($0) }
        let due = open.first { moment in
            guard let time = minutes(moment.time) else { return false }
            return time <= nowMinutes && nowMinutes - time <= graceMinutes
        }
        if let due { return due }
        return open.first { (minutes($0.time) ?? -1) > nowMinutes }
    }

    /// Butoanele apar cu cel mult o jumătate de oră înainte (nimeni nu confirmă din greșeală cina la prânz).
    static func isDue(_ moment: Moment, nowMinutes: Int) -> Bool {
        guard let time = minutes(moment.time) else { return false }
        return time <= nowMinutes + earlyMinutes
    }

    /// Ora dozei pentru POST /doses: ziua programului + ora momentului, în fusul telefonului.
    static func scheduledAt(day: String, time: String, calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let minutes = minutes(time) else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = minutes / 60
        components.minute = minutes % 60
        return calendar.date(from: components)
    }

    /// „2026-11-15” pentru ziua de după `day`
    static func nextDay(after day: String, calendar: Calendar = .current) -> String? {
        guard let start = scheduledAt(day: day, time: "12:00", calendar: calendar),
              let next = calendar.date(byAdding: .day, value: 1, to: start)
        else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: next)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// „o pastilă”, „jumătate de pastilă”, „o capsulă și jumătate”
    static func quantityWords(_ qty: Double, form: String?) -> String {
        let capsule = form?.lowercased().contains("caps") == true
        let one = capsule ? "o capsulă" : "o pastilă"
        let many = capsule ? "capsule" : "pastile"
        let half = capsule ? "jumătate de capsulă" : "jumătate de pastilă"
        let whole = Int(qty.rounded(.down))
        let hasHalf = qty - Double(whole) >= 0.25
        switch (whole, hasHalf) {
        case (0, _): return half
        case (1, false): return one
        case (1, true): return "\(one) și jumătate"
        case (2, false): return "două \(many)"
        case (2, true): return "două \(many) și jumătate"
        default: return hasHalf ? "\(whole) \(many) și jumătate" : "\(whole) \(many)"
        }
    }

    /// „ora 13”, „ora 7 și 30”: cum se spune ora cu voce tare
    static func spokenClock(_ clock: String) -> String {
        guard let minutes = minutes(clock) else { return clock }
        let hour = minutes / 60
        let minute = minutes % 60
        return minute == 0 ? "ora \(hour)" : "ora \(hour) și \(minute)"
    }

    /// „Ați terminat” doar când chiar s-a confirmat tot; altfel un text neutru, fără îndemn la doza ratată.
    static func dayEnd(_ moments: [Moment], isDone: (Moment) -> Bool) -> DayEnd {
        if moments.isEmpty { return .empty }
        return moments.allSatisfy(isDone) ? .allDone : .nothingNow
    }

    static func dayEndTitle(_ end: DayEnd) -> String {
        switch end {
        case .empty: "Nu aveți pastile în program."
        case .allDone: "Ați terminat pastilele de azi."
        case .nothingNow: "Pentru azi nu mai e nimic de luat acum."
        }
    }

    /// „Mâine, primele sunt la ora 07:00.”; nimic când programul e gol
    static func tomorrowLine(_ moments: [Moment]) -> String? {
        moments.first.map { "Mâine, primele sunt la ora \($0.time)." }
    }

    /// Ce citește vocea la deschidere și la butonul de difuzor.
    static func momentSpeech(_ moment: Moment?, doseLines: [String], due: Bool, dayEnd: DayEnd = .allDone) -> String {
        guard let moment else { return dayEndTitle(dayEnd) }
        let head = due
            ? "\(moment.label). Pastilele de la \(spokenClock(moment.time))."
            : "Următoarele pastile sunt la \(spokenClock(moment.time)), \(moment.label.lowercased())."
        return ([head] + doseLines).joined(separator: " ")
    }

    /// „Foarte bine. Următoarele pastile sunt la ora 13.”
    static func afterAction(_ status: DoseStatus, next: Moment?, allDone: Bool = true) -> String {
        let first = status == .taken ? "Foarte bine." : "Am notat."
        guard let next else {
            return "\(first) \(dayEndTitle(allDone ? .allDone : .nothingNow))"
        }
        return "\(first) Următoarele pastile sunt la \(spokenClock(next.time))."
    }

    /// „pe stomacul gol” → „Pe stomacul gol”
    static func sentence(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
