import SwiftUI

enum SeniorRoute: Hashable {
    case day
}

/// Modul senior: o singură stivă de navigare, fără tab-uri. „Acum” e ecranul principal,
/// „Ziua de azi” e un nivel mai jos.
struct SeniorRoot: View {
    @State private var path: [SeniorRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            NowView(onShowDay: { path.append(.day) })
                .navigationDestination(for: SeniorRoute.self) { route in
                    switch route {
                    case .day: DayView()
                    }
                }
        }
    }
}
