import Foundation
import UserNotifications

/// Notificările locale ale modului senior: câte una la fiecare moment din program, pentru azi și mâine,
/// refăcute după orice schimbare a programului sau a confirmărilor.
enum Reminders {
    static let prefix = "pg.moment."
    static let snoozeID = "pg.snooze"

    /// ținut aici: centrul de notificări păstrează delegatul doar ca referință slabă
    static let presenter = ForegroundPresenter()

    struct Planned: Equatable {
        let id: String
        let date: Date
        let title: String
        let body: String
    }

    /// Se cheamă la pornire, ca notificarea să apară și cu aplicația deschisă.
    static func installPresenter() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    static func needsPermission() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Ce notificări trebuie să existe; momentele de azi deja confirmate sau trecute nu mai sună.
    /// Programul de mâine e presupus același cu cel de azi (se reface oricum la prima deschidere).
    static func plan(
        schedule: Schedule,
        names: (String) -> String,
        isDone: (Moment) -> Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> [Planned] {
        let days = [schedule.date] + [SeniorDay.nextDay(after: schedule.date, calendar: calendar)].compactMap { $0 }
        var result: [Planned] = []
        for (index, day) in days.enumerated() {
            for moment in schedule.moments {
                if index == 0 && isDone(moment) { continue }
                guard let date = SeniorDay.scheduledAt(day: day, time: moment.time, calendar: calendar), date > now
                else { continue }
                let body = moment.doses.map { names($0.medid) }.filter { !$0.isEmpty }.joined(separator: ", ")
                result.append(Planned(id: prefix + day + "T" + moment.time, date: date, title: moment.label, body: body))
            }
        }
        return result
    }

    static func replaceAll(with planned: [Planned]) async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for item in planned {
            try? await center.add(request(for: item))
        }
    }

    /// „Mai târziu”: o singură reamintire, care o înlocuiește pe cea de dinainte.
    static func remind(at date: Date, title: String, body: String) async {
        guard await isAuthorized() else { return }
        let item = Planned(id: snoozeID, date: date, title: title, body: body)
        try? await UNUserNotificationCenter.current().add(request(for: item))
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func request(for item: Planned) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
    }
}

/// Fără delegat, iOS nu arată notificarea cât aplicația e deschisă. `nonisolated`: centrul de notificări
/// îl cheamă de pe firul lui.
nonisolated final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
