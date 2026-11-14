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
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [SeniorRoute] = []
    /// doar revenirea din fundal reîncarcă (nu și Centrul de control, care trece prin `.inactive`)
    @State private var wasInBackground = false

    var body: some View {
        NavigationStack(path: $path) {
            NowView(onShowDay: { path.append(.day) }, onCheckIn: { path.append(.checkIn) })
                .modifier(SeniorNavigationBar())
                .navigationDestination(for: SeniorRoute.self) { route in
                    Group {
                        switch route {
                        case .day:
                            DayView(onOpenMoment: { path.append(.moment($0)) }, onBack: { path.removeAll() })
                        case .moment(let time):
                            NowView(pinnedTime: time)
                        case .checkIn:
                            VoiceCheckInView()
                        }
                    }
                    .modifier(SeniorNavigationBar())
                }
        }
        // notificările se refac după orice schimbare a programului
        .task(id: scheduleSignature) { await store.rescheduleReminders() }
        // Q3-06: Maria revine în aplicație după ore (sau a doua zi) și vede programul de acum
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                wasInBackground = true
            case .active:
                store.doseLog.retryUnsent()
                guard wasInBackground else { return }
                wasInBackground = false
                Task { await store.refreshAll() }
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await store.refreshIfNewDay() }
        }
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

/// 2.4.2: suprafețe opace în modul senior, inclusiv bara de navigare (Q3-26).
private struct SeniorNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(PgColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
