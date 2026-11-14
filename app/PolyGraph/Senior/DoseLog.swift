import Foundation
import Observation

/// Ce a confirmat pacientul azi: „Am luat”, „Am sărit”, „Mai târziu” și „Anulează”.
/// Starea se schimbă imediat pe telefon (și rămâne după repornire), iar POST /doses pleacă în spate;
/// serverul e idempotent pe med_id + scheduled_at, deci retrimiterea nu dublează nimic.
/// Ce n-a ajuns la server stă în `UserDefaults` și se retrimite la 30 s, la revenirea în aplicație
/// și la reîncărcare, chiar după repornirea telefonului (Q3-07).
@Observable
final class DoseLog {
    static let undoWindow: Duration = .seconds(5)
    static let retryInterval: Duration = .seconds(30)

    /// Ultima confirmare, cât încă se poate anula din banner.
    struct Undo: Equatable {
        let day: String
        let time: String
        let status: DoseStatus
        let medIDs: [String]
        /// starea dozelor de dinainte (lipsă = neconfirmată)
        let previous: [String: DoseStatus]
    }

    private(set) var statuses: [String: DoseStatus]
    private(set) var undo: Undo?
    /// „Mai târziu”: momentul (zi + oră) → ora la care îi reamintim
    private(set) var snoozes: [String: Date] = [:]
    /// ultima eroare de trimitere; dozele rămân de retrimis
    private(set) var lastError: String?

    @ObservationIgnored private let send: (Dose) async throws -> Void
    @ObservationIgnored private let guarded: GuardedAction
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let undoDelay: Duration
    @ObservationIgnored private let retryDelay: Duration
    @ObservationIgnored private var undoTimer: Task<Void, Never>?
    @ObservationIgnored private var retryTimer: Task<Void, Never>?
    @ObservationIgnored private var unsent: [Dose] = [] {
        didSet { persistUnsent() }
    }
    @ObservationIgnored private var isSending = false

    private static let storageKey = "pg.doseLog"
    private static let unsentKey = "pg.doseLog.unsent"

    init(
        defaults: UserDefaults = .standard,
        undoDelay: Duration = DoseLog.undoWindow,
        retryDelay: Duration = DoseLog.retryInterval,
        guarded: GuardedAction = GuardedAction(interval: GuardedAction.seniorInterval),
        send: @escaping (Dose) async throws -> Void = { _ in }
    ) {
        self.defaults = defaults
        self.undoDelay = undoDelay
        self.retryDelay = retryDelay
        self.guarded = guarded
        self.send = send
        let stored = defaults.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
        statuses = stored.compactMapValues(DoseStatus.init(rawValue:))
        if let data = defaults.data(forKey: Self.unsentKey),
           let doses = try? JSONCoding.decoder.decode([Dose].self, from: data) {
            unsent = doses
        }
    }

    /// Confirmări care încă n-au ajuns la server.
    var unsentCount: Int { unsent.count }

    static func key(day: String, time: String, medID: String) -> String {
        "\(day)T\(time)|\(medID)"
    }

    private static func momentKey(day: String, time: String) -> String {
        "\(day)T\(time)"
    }

    // MARK: - Citire

    func status(day: String, time: String, medID: String) -> DoseStatus? {
        statuses[Self.key(day: day, time: time, medID: medID)]
    }

    func momentStatus(_ moment: Moment, day: String) -> MomentStatus {
        let all = moment.doses.map { status(day: day, time: moment.time, medID: $0.medid) }
        guard !all.isEmpty, all.allSatisfy({ $0 == .taken || $0 == .skipped }) else { return .open }
        return all.contains(.taken) ? .taken : .skipped
    }

    func isDone(_ moment: Moment, day: String) -> Bool {
        momentStatus(moment, day: day) != .open
    }

    func snoozedUntil(_ moment: Moment, day: String) -> Date? {
        snoozes[Self.momentKey(day: day, time: moment.time)]
    }

    // MARK: - Acțiuni

    /// „Am luat” / „Am sărit” pentru tot momentul. A doua apăsare din aceeași secundă și un moment
    /// deja confirmat nu mai trimit nimic (T-A4-02). Întoarce trimiterea, sau `nil` dacă n-a făcut nimic.
    @discardableResult
    func record(_ status: DoseStatus, moment: Moment, day: String) -> Task<Void, Never>? {
        guard status != .pending, momentStatus(moment, day: day) == .open else { return nil }
        var task: Task<Void, Never>?
        guarded({
            task = apply(status, moment: moment, day: day)
        })
        return task
    }

    /// „Anulează” din banner: dozele redevin neconfirmate și pleacă cu `pending`.
    @discardableResult
    func undoLast() -> Task<Void, Never>? {
        guard let undo else { return nil }
        undoTimer?.cancel()
        undoTimer = nil
        self.undo = nil
        var doses: [Dose] = []
        for medID in undo.medIDs {
            let key = Self.key(day: undo.day, time: undo.time, medID: medID)
            statuses[key] = undo.previous[key]
            if let at = SeniorDay.scheduledAt(day: undo.day, time: undo.time) {
                doses.append(Dose(medid: medID, recordedAt: nil, scheduledAt: at, status: .pending))
            }
        }
        persist()
        return post(doses)
    }

    /// „Mai târziu”: doar pe telefon (contractul nu are stare pentru amânare); întoarce ora reamintirii.
    @discardableResult
    func snooze(_ moment: Moment, day: String, now: Date) -> Date? {
        var until: Date?
        guarded({
            let date = now.addingTimeInterval(TimeInterval(SeniorDay.snoozeMinutes * 60))
            snoozes[Self.momentKey(day: day, time: moment.time)] = date
            until = date
        })
        return until
    }

    /// Retrimite ce n-a ajuns la server (la reîncărcare, la revenirea în aplicație și la 30 s).
    @discardableResult
    func retryUnsent() -> Task<Void, Never>? {
        guard !unsent.isEmpty else { return nil }
        return post([])
    }

    /// La deconectare sau la pacientul demo refăcut: nimic din ziua veche nu mai contează.
    func clear() {
        undoTimer?.cancel()
        undoTimer = nil
        retryTimer?.cancel()
        retryTimer = nil
        undo = nil
        statuses = [:]
        snoozes = [:]
        unsent = []
        lastError = nil
        persist()
    }

    // MARK: - Intern

    private func apply(_ status: DoseStatus, moment: Moment, day: String) -> Task<Void, Never> {
        // doar ziua curentă contează; restul se uită
        statuses = statuses.filter { $0.key.hasPrefix(day) }
        var previous: [String: DoseStatus] = [:]
        var doses: [Dose] = []
        for dose in moment.doses {
            let key = Self.key(day: day, time: moment.time, medID: dose.medid)
            previous[key] = statuses[key]
            statuses[key] = status
            if let at = SeniorDay.scheduledAt(day: day, time: moment.time) {
                doses.append(Dose(medid: dose.medid, recordedAt: nil, scheduledAt: at, status: status))
            }
        }
        snoozes[Self.momentKey(day: day, time: moment.time)] = nil
        persist()
        startUndo(Undo(
            day: day, time: moment.time, status: status, medIDs: moment.doses.map(\.medid), previous: previous))
        return post(doses)
    }

    private func startUndo(_ undo: Undo) {
        undoTimer?.cancel()
        self.undo = undo
        undoTimer = Task { [weak self, undoDelay] in
            try? await Task.sleep(for: undoDelay)
            guard !Task.isCancelled else { return }
            withPgAnimation(.pgStandard) {
                self?.undo = nil
            }
        }
    }

    /// Trimite în ordine (o anulare nu poate ajunge înaintea confirmării pe care o anulează).
    @discardableResult
    private func post(_ doses: [Dose]) -> Task<Void, Never> {
        unsent.append(contentsOf: doses)
        return Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        while let dose = unsent.first {
            do {
                try await send(dose)
                unsent.removeFirst()
                lastError = nil
            } catch let error where Self.isPermanent(error) {
                // serverul a refuzat doza (ex. medicamentul a fost șters): retrimiterea n-ar ajuta,
                // iar restul cozii nu trebuie să aștepte după ea
                unsent.removeFirst()
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? "Nu am putut trimite confirmarea."
                scheduleRetry()
                return
            }
        }
        retryTimer?.cancel()
        retryTimer = nil
    }

    private func scheduleRetry() {
        retryTimer?.cancel()
        retryTimer = Task { [weak self, retryDelay] in
            try? await Task.sleep(for: retryDelay)
            guard !Task.isCancelled else { return }
            self?.retryUnsent()
        }
    }

    /// 4xx (în afară de 408 / 429): cererea e greșită, nu rețeaua.
    private static func isPermanent(_ error: Error) -> Bool {
        guard case .http(let status, _) = error as? APIError else { return false }
        return (400..<500).contains(status) && status != 408 && status != 429
    }

    private func persist() {
        defaults.set(statuses.mapValues(\.rawValue), forKey: Self.storageKey)
    }

    private func persistUnsent() {
        if unsent.isEmpty {
            defaults.removeObject(forKey: Self.unsentKey)
        } else if let data = try? JSONCoding.encoder.encode(unsent) {
            defaults.set(data, forKey: Self.unsentKey)
        }
    }
}
