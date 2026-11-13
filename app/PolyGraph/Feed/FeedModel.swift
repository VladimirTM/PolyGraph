import Foundation
import Observation
import UserNotifications

/// Noutățile aparținătorului: polling la 10 s pe GET /feed?since=. Evenimentele noi intră sus doar
/// dacă lista e la început; altfel așteaptă în `pendingNew` (pastila „3 noutăți ↑”), ca lista să nu se
/// miște sub degetul cuiva. Cele grave aduc o notificare locală și haptic.
@Observable
final class FeedModel {
    static let interval: Duration = .seconds(10)

    /// cele mai noi primele
    private(set) var events: [FeedEvent] = []
    /// sosite cât timp lista nu era la început
    private(set) var pendingNew: [FeedEvent] = []
    private(set) var hasLoaded = false
    private(set) var lastError: String?
    /// crește la fiecare lot cu evenimente grave (trigger pentru `.sensoryFeedback(.warning)`)
    private(set) var alarmCount = 0
    private(set) var isAtTop = true

    @ObservationIgnored private var seen: Set<String> = []
    @ObservationIgnored private var isPolling = false
    @ObservationIgnored private let fetch: (Date?) async throws -> [FeedEvent]
    @ObservationIgnored private let notify: (FeedEvent) -> Void

    init(
        fetch: @escaping (Date?) async throws -> [FeedEvent] = { _ in [] },
        notify: @escaping (FeedEvent) -> Void = { _ in }
    ) {
        self.fetch = fetch
        self.notify = notify
    }

    func event(id: String) -> FeedEvent? {
        events.first { $0.id == id } ?? pendingNew.first { $0.id == id }
    }

    /// Check-in-urile apar în feed doar când sunt escaladate; alertele contează de la `major` în sus.
    static func isSerious(_ event: FeedEvent) -> Bool {
        event.type == .checkin || event.severity == .critical || event.severity == .major
    }

    func poll() async {
        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }
        let since = (pendingNew.first ?? events.first)?.at
        do {
            receive(try await fetch(since))
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "Nu am putut încărca noutățile."
        }
    }

    /// Deduplicare pe `id` (T-A5-02): același eveniment venit de două ori apare o singură dată.
    /// Primul lot e istoricul: fără notificări.
    func receive(_ batch: [FeedEvent]) {
        let fresh = batch.filter { seen.insert($0.id).inserted }.sorted { $0.at > $1.at }
        guard hasLoaded else {
            events = fresh
            hasLoaded = true
            return
        }
        guard !fresh.isEmpty else { return }
        withPgAnimation(.pgStandard) {
            if isAtTop {
                events.insert(contentsOf: fresh, at: 0)
            } else {
                pendingNew.insert(contentsOf: fresh, at: 0)
            }
        }
        let serious = fresh.filter { Self.isSerious($0) }
        guard !serious.isEmpty else { return }
        alarmCount += 1
        serious.forEach(notify)
    }

    func setAtTop(_ value: Bool) {
        guard value != isAtTop else { return }
        isAtTop = value
        if value && !pendingNew.isEmpty { showPending() }
    }

    func showPending() {
        guard !pendingNew.isEmpty else { return }
        withPgAnimation(.pgStandard) {
            events.insert(contentsOf: pendingNew, at: 0)
            pendingNew = []
        }
    }

    func reset() {
        events = []
        pendingNew = []
        seen = []
        hasLoaded = false
        lastError = nil
        isAtTop = true
    }
}

/// Notificarea imediată pentru un eveniment grav din Noutăți (aplicația deschisă; fără APNs).
enum FeedAlerts {
    static func notify(_ event: FeedEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "pg.feed.\(event.id)", content: content, trigger: trigger))
    }

    static func requestPermissionIfNeeded() async {
        if await Reminders.needsPermission() {
            await Reminders.requestPermission()
        }
    }
}

extension FeedEvent {
    /// Check-in: „Maria a raportat: amețeală, vânătăi” → ["amețeală", "vânătăi"]
    var symptomLabels: [String] {
        guard type == .checkin, let range = title.range(of: ": ") else { return [] }
        return title[range.upperBound...].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Titlul fără simptome (ele apar ca chip-uri): „Maria a raportat”
    var shortTitle: String {
        guard type == .checkin, let range = title.range(of: ": ") else { return title }
        return String(title[..<range.lowerBound])
    }
}

extension FeedEventType {
    var label: String {
        switch self {
        case .alertNew: "Alertă nouă"
        case .doseMissed: "Doză ratată"
        case .checkin: "Check-in"
        case .doctorReviewed: "Decizia medicului de familie"
        }
    }

    var systemImage: String {
        switch self {
        case .alertNew: "exclamationmark.triangle"
        case .doseMissed: "clock.badge.exclamationmark"
        case .checkin: "waveform"
        case .doctorReviewed: "checkmark.seal"
        }
    }
}
