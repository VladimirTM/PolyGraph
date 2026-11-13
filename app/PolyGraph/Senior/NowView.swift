import SwiftUI

/// Ecranul „Acum” (schelet A1): ora, următorul moment din program și drumul spre „Ziua de azi”.
/// Cardurile de doză, „Am luat” și vocea vin la A4.
struct NowView: View {
    @Environment(AppStore.self) private var store
    let onShowDay: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                TimelineView(.everyMinute) { _ in
                    let now = store.clock.now
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(PgFormat.clock(now))
                            .font(.system(size: clockSize, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(PgColor.textPrimary)
                        Text(PgFormat.longDay(now))
                            .font(.system(size: textSize))
                            .foregroundStyle(PgColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("now.clock")
                }

                nextMomentCard

                SeniorButton(
                    "Ziua de azi", systemImage: "calendar", prominence: .secondary,
                    identifier: "now.dayButton", action: onShowDay)
            }
            .padding(Spacing.m)
        }
        .background(PgColor.background)
        .navigationTitle("Acum")
        .navigationBarTitleDisplayMode(.inline)
        .pgSettingsToolbar()
        .refreshable { await store.refreshAll() }
    }

    @ViewBuilder
    private var nextMomentCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let schedule = store.schedule {
                if let moment = nextMoment(in: schedule) {
                    Text("Următorul: \(moment.label.lowercased())")
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(PgColor.textPrimary)
                    Text("La ora \(moment.time), \(PgFormat.medicationCount(moment.doses.count)).")
                        .font(.system(size: textSize))
                        .foregroundStyle(PgColor.textPrimary)
                } else {
                    Text("Ați terminat medicamentele de azi.")
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(PgColor.textPrimary)
                }
            } else if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: ControlHeight.senior)
            } else {
                Text("Nu am putut încărca programul.")
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(PgColor.textPrimary)
                Text("Trageți ecranul în jos ca să încercăm din nou.")
                    .font(.system(size: textSize))
                    .foregroundStyle(PgColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.calmCard))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("now.nextMomentCard")
    }

    /// Primul moment de la ora curentă încolo; orele „HH:MM” se compară corect ca text.
    private func nextMoment(in schedule: Schedule) -> Moment? {
        let now = PgFormat.clock(store.clock.now)
        return schedule.moments.first { $0.time >= now }
    }
}
