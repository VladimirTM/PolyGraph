import Foundation

/// Când se oprește singur microfonul: după 2 s de liniște (doar după ce s-a vorbit ceva), după 4 s fără
/// cuvinte noi (sala e zgomotoasă și nivelul nu mai scade sub prag) sau după 60 s.
struct SilenceDetector {
    enum Decision: Equatable {
        case listen
        case stopSilence
        case stopLimit
    }

    /// nivelul 0…1 (din dB, vezi `Listener`) sub care socotim că e liniște
    static let threshold: Float = 0.2

    let silence: TimeInterval
    let stall: TimeInterval
    let limit: TimeInterval

    private(set) var hasSpoken = false
    private var startedAt: TimeInterval?
    private var quietSince: TimeInterval?
    private var lastWords: TimeInterval?

    init(silence: TimeInterval = 2, stall: TimeInterval = 4, limit: TimeInterval = 60) {
        self.silence = silence
        self.stall = stall
        self.limit = limit
    }

    /// Recunoașterea a dat text nou: e vorbire, chiar dacă nivelul e mic.
    mutating func noteWords(at time: TimeInterval) {
        hasSpoken = true
        lastWords = time
        quietSince = nil
    }

    /// Se cheamă de ~10 ori pe secundă cu ultimul nivel.
    mutating func feed(level: Float, at time: TimeInterval) -> Decision {
        let start = startedAt ?? time
        startedAt = start
        if time - start >= limit { return .stopLimit }
        if hasSpoken, let lastWords, time - lastWords >= stall { return .stopSilence }
        if level >= Self.threshold {
            hasSpoken = true
            quietSince = nil
            return .listen
        }
        guard hasSpoken else { return .listen }
        let since = quietSince ?? time
        quietSince = since
        return time - since >= silence ? .stopSilence : .listen
    }
}
