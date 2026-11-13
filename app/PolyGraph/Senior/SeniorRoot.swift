import SwiftUI

enum SeniorRoute: Hashable {
    case day
    /// un moment ales din „Ziua de azi”, după ora lui („07:30”)
    case moment(String)
    case checkIn
}

/// Modul senior: o singură stivă de navigare, fără tab-uri. „Acum” e ecranul principal,
/// „Ziua de azi” e un nivel mai jos, iar un moment din zi încă unul.
struct SeniorRoot: View {
    @Environment(AppStore.self) private var store
    @State private var path: [SeniorRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            NowView(onShowDay: { path.append(.day) }, onCheckIn: { path.append(.checkIn) })
                .navigationDestination(for: SeniorRoute.self) { route in
                    switch route {
                    case .day:
                        DayView(onOpenMoment: { path.append(.moment($0)) })
                    case .moment(let time):
                        NowView(pinnedTime: time)
                    case .checkIn:
                        VoiceCheckInView()
                    }
                }
        }
        // notificările se refac după orice schimbare a programului
        .task(id: scheduleSignature) { await store.rescheduleReminders() }
    }

    /// ziua + orele + medicamentele fiecărui moment
    private var scheduleSignature: String {
        guard let schedule = store.schedule else { return "" }
        let moments = schedule.moments.map { moment in
            moment.time + ":" + moment.doses.map(\.medid).joined(separator: ",")
        }
        return ([schedule.date] + moments).joined(separator: "|")
    }
}
