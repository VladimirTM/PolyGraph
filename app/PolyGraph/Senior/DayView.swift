import SwiftUI

/// „Ziua de azi” (schelet A1): momentele din program, cu medicamentele fiecăruia.
/// Cronologia cu bife vine la A4.
struct DayView: View {
    @Environment(AppStore.self) private var store

    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let schedule = store.schedule {
                    ForEach(schedule.moments) { moment in
                        momentCard(moment)
                    }
                } else if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: ControlHeight.senior)
                } else {
                    Text("Nu am putut încărca programul. Trageți ecranul în jos ca să încercăm din nou.")
                        .font(.system(size: textSize))
                        .foregroundStyle(PgColor.textPrimary)
                }
            }
            .padding(Spacing.m)
        }
        .background(PgColor.background)
        .navigationTitle("Ziua de azi")
        .refreshable { await store.refreshAll() }
    }

    private func momentCard(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(moment.time)
                    .monospacedDigit()
                Text(moment.label)
            }
            .font(.system(size: titleSize, weight: .semibold))
            .foregroundStyle(PgColor.textPrimary)

            ForEach(Array(moment.doses.enumerated()), id: \.offset) { _, dose in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(store.med(id: dose.medid)?.displayName ?? dose.medid)
                        .font(.system(size: textSize, weight: .semibold))
                    Text(dose.instruction)
                        .font(.system(size: textSize))
                }
                .foregroundStyle(PgColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.surface))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("day.moment.\(moment.time)")
    }
}
