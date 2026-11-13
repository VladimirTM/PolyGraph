import OSLog

/// `log show --predicate 'subsystem == "ro.polygraph"'` le adună pe toate (folosit de turul de review).
enum Log {
    static let subsystem = "ro.polygraph"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let api = Logger(subsystem: subsystem, category: "api")
    static let onboarding = Logger(subsystem: subsystem, category: "onboarding")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let graph = Logger(subsystem: subsystem, category: "graph")
    static let share = Logger(subsystem: subsystem, category: "share")
    static let demo = Logger(subsystem: subsystem, category: "demo")
}
