import Foundation

/// Hook-urile pentru turul de review pe simulator (plan, tabelul Q0). Se citesc doar în build-ul Debug;
/// în Release obiectul e mereu gol, deci aplicația livrată nu poate fi pornită în aceste moduri.
/// `nonisolated`: se citește și din `EnvironmentValues`, care nu e legat de main actor.
nonisolated struct DebugEnvironment {
    var baseURL: String?
    var role: AppRole?
    var skipOnboarding = false
    var resetDemo = false
    /// `sintrom`, `klacid_rx`, `unreadable`…: camera falsă din A2
    var fakeScan: String?
    /// textul pe care `Listener` îl emite în locul microfonului (A5)
    var fakeTranscript: String?
    var now: Date?
    var reduceMotion = false

    init() {}

    static let current: DebugEnvironment = {
        #if DEBUG
        DebugEnvironment(environment: ProcessInfo.processInfo.environment)
        #else
        DebugEnvironment()
        #endif
    }()

    #if DEBUG
    init(environment env: [String: String]) {
        func text(_ key: String) -> String? {
            guard let value = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return value
        }
        func flag(_ key: String) -> Bool {
            ["1", "true", "yes"].contains(text(key)?.lowercased() ?? "")
        }

        baseURL = text("PG_BASE_URL")
        role = text("PG_ROLE").flatMap { AppRole(rawValue: $0.lowercased()) }
        skipOnboarding = flag("PG_SKIP_ONBOARDING")
        resetDemo = flag("PG_RESET_DEMO")
        fakeScan = text("PG_FAKE_SCAN")
        fakeTranscript = text("PG_FAKE_TRANSCRIPT")
        now = text("PG_NOW").flatMap(Self.parseNow)
        reduceMotion = flag("PG_REDUCE_MOTION")
    }

    /// ISO 8601 cu fus orar (`2026-11-14T08:05:00+02:00`) sau fără, caz în care e ora locală a telefonului.
    static func parseNow(_ text: String) -> Date? {
        if let date = JSONCoding.parseISO8601(text) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
    #endif
}
