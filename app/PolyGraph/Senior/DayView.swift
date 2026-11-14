import SwiftUI

/// „Ziua de azi”: cronologia momentelor, de sus în jos, cu starea fiecăruia în cuvinte și cu pictogramă.
/// Atingerea unui rând deschide momentul acela, cu aceleași detalii și butoane ca „Acum”.
struct DayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let onOpenMoment: (String) -> Void
    /// „Înapoi la Acum”: ieșire de 72 pt, nu doar butonul de înapoi de 44 pt sau swipe (Q3-25)
    var onBack: () -> Void = {}
    @State private var isSharing = false

    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22
    /// fix: la textul mare, pozele care cresc odată cu textul împing rândul peste marginea ecranului
    private let thumbnail: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let schedule = store.schedule {
                    if schedule.moments.isEmpty {
                        emptyDay
                    }
                    ForEach(schedule.moments) { moment in
                        row(moment, day: schedule.date)
                    }
                } else if store.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: ControlHeight.senior)
                } else {
                    loadError
                }
                // codul nu se poate arăta medicului cât programul nu s-a încărcat
                if store.schedule != nil || store.isLoading {
                    SeniorButton(
                        "Arată medicului", systemImage: "qrcode", prominence: .secondary,
                        identifier: "day.shareButton"
                    ) {
                        isSharing = true
                    }
                    .padding(.top, Spacing.s)
                }
                SeniorButton(
                    "Înapoi la Acum", systemImage: "chevron.backward", prominence: .secondary,
                    identifier: "day.backButton", action: onBack)
            }
            .padding(Spacing.m)
        }
        .background(PgColor.background)
        .navigationTitle("Ziua de azi")
        .refreshable { await store.refreshAll() }
        .sheet(isPresented: $isSharing) {
            ShareSheet(audience: .senior)
                .environment(store)
        }
    }

    private var emptyDay: some View {
        Text(SeniorDay.dayEndTitle(.empty))
            .font(.system(size: titleSize, weight: .semibold))
            .foregroundStyle(PgColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                    .fill(PgColor.calmCard))
            .accessibilityIdentifier("day.empty")
    }

    /// Eroarea se repară cu un buton mare, nu cu un gest (2.4.2, Q3-05).
    private var loadError: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Nu am putut încărca programul.")
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(PgColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("day.error")
            SeniorButton(
                "Încearcă din nou", systemImage: "arrow.clockwise", prominence: .secondary,
                identifier: "day.retryButton"
            ) {
                Task { await store.refreshAll() }
            }
        }
    }

    private func row(_ moment: Moment, day: String) -> some View {
        let state = rowState(moment, day: day)
        return Button {
            onOpenMoment(moment.time)
        } label: {
            HStack(alignment: .center, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    timeAndLabel(moment)
                    photos(moment)
                    Label(state.text, systemImage: state.icon)
                        .font(.system(size: textSize, weight: .semibold))
                        .foregroundStyle(state.isDone ? PgColor.accent : PgColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // la textul de accesibilitate săgeata fură lățime; tot cardul rămâne apăsabil
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .font(.system(size: textSize, weight: .semibold))
                        .foregroundStyle(PgColor.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(PgColor.textPrimary)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                    .fill(state.isCurrent ? PgColor.calmCard : PgColor.surface))
            .contentShape(RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Ora \(moment.time), \(moment.label). \(medNames(moment)). \(state.text).")
        .accessibilityHint("Deschide pastilele de la ora \(moment.time)")
        .accessibilityIdentifier("day.moment.\(moment.time)")
    }

    /// Ora și eticheta pe același rând; la textul de accesibilitate, una sub alta.
    private func timeAndLabel(_ moment: Moment) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s))
        return layout {
            Text(moment.time)
                .font(.system(size: titleSize, weight: .semibold))
                .monospacedDigit()
            Text(moment.label)
                .font(.system(size: textSize))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func photos(_ moment: Moment) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(moment.doses, id: \.medid) { dose in
                AsyncImage(url: store.api.mediaURL(store.med(id: dose.medid)?.photourl)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "pills")
                            .foregroundStyle(PgColor.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(PgColor.calmCard)
                    }
                }
                .frame(width: thumbnail, height: thumbnail)
                .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }

    private struct RowState {
        let text: String
        let icon: String
        let isDone: Bool
        let isCurrent: Bool
    }

    private func rowState(_ moment: Moment, day: String) -> RowState {
        let now = store.clock.now
        let nowMinutes = SeniorDay.minutes(of: now)
        let current = SeniorDay.currentMoment(in: store.schedule?.moments ?? [], nowMinutes: nowMinutes) {
            store.doseLog.isDone($0, day: day)
        }
        let isCurrent = current?.time == moment.time
        switch store.doseLog.momentStatus(moment, day: day) {
        case .taken:
            return RowState(text: "Luate", icon: "checkmark.circle.fill", isDone: true, isCurrent: false)
        case .skipped:
            return RowState(text: "Sărite", icon: "minus.circle", isDone: true, isCurrent: false)
        case .open:
            let time = SeniorDay.minutes(moment.time) ?? 0
            if isCurrent && time <= nowMinutes + SeniorDay.earlyMinutes {
                return RowState(text: "De luat acum", icon: "bell", isDone: false, isCurrent: true)
            }
            if time < nowMinutes {
                return RowState(text: "Neconfirmate", icon: "circle", isDone: false, isCurrent: isCurrent)
            }
            return RowState(text: "Urmează", icon: "clock", isDone: false, isCurrent: isCurrent)
        }
    }

    private func medNames(_ moment: Moment) -> String {
        moment.doses.map { store.med(id: $0.medid)?.product.brand ?? "medicament" }.joined(separator: ", ")
    }
}
