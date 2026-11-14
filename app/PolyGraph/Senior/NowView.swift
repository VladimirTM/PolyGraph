import SwiftUI

/// Ecranul „Acum” al pacientului: un singur moment, cu pastilele lui și trei butoane mari.
/// Din „Ziua de azi” se deschide același ecran, fixat pe momentul ales (`pinnedTime`).
struct NowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.pgReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// `nil`: momentul curent, care avansează după „Am luat”; altfel momentul ales din „Ziua de azi”
    let pinnedTime: String?
    let onShowDay: () -> Void
    let onCheckIn: () -> Void

    @Namespace private var flight
    /// momentul a cărui bifă mare e pe ecran, înainte să zboare în cronologie
    @State private var flyingCheck: String?
    @State private var flightTask: Task<Void, Never>?
    @State private var takenCount = 0
    @State private var didAutoRead = false
    @State private var askReminders = false

    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22
    @ScaledMetric(relativeTo: .largeTitle) private var bigCheckSize: CGFloat = 160

    init(pinnedTime: String? = nil, onShowDay: @escaping () -> Void = {}, onCheckIn: @escaping () -> Void = {}) {
        self.pinnedTime = pinnedTime
        self.onShowDay = onShowDay
        self.onCheckIn = onCheckIn
    }

    private var log: DoseLog { store.doseLog }

    var body: some View {
        TimelineView(.everyMinute) { _ in
            screen(now: store.clock.now)
        }
        .background(PgColor.background)
        .navigationTitle(pinnedTime == nil ? "Acum" : displayedMoment(now: store.clock.now)?.label ?? "Moment")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(SettingsToolbarIf(isOn: pinnedTime == nil))
        .refreshable { await store.refreshAll() }
        .sensoryFeedback(.success, trigger: takenCount)
        .task(id: store.schedule?.date) { await readOnOpen() }
        .task { await checkReminderPermission() }
    }

    // MARK: - Ecranul

    private func screen(now: Date) -> some View {
        let moment = displayedMoment(now: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let schedule = store.schedule {
                    header(schedule: schedule, moment: moment, now: now)
                    if let moment {
                        VStack(spacing: Spacing.m) {
                            ForEach(moment.doses, id: \.medid) { dose in
                                DoseCard(
                                    dose: dose, med: store.med(id: dose.medid),
                                    photoURL: store.api.mediaURL(store.med(id: dose.medid)?.photourl))
                            }
                        }
                        .id(moment.time)
                        .transition(cardTransition)
                        // la textul de accesibilitate bara de jos ține doar „Am luat”; restul vine după pastile
                        if splitsActions, showsActions(moment: moment, now: now) {
                            secondaryActions(moment: moment, vertical: true)
                                .transition(.opacity)
                        }
                    } else {
                        dayDone(schedule)
                            .transition(cardTransition)
                    }
                } else if store.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: ControlHeight.senior)
                } else {
                    loadError
                }

                // după pastile: ce se ia e primul lucru de pe ecran, și în AX (Q3-02)
                notices

                if pinnedTime == nil {
                    SeniorButton(
                        "Ziua de azi", systemImage: "calendar", prominence: .secondary,
                        identifier: "now.dayButton", action: onShowDay)
                    SeniorButton(
                        "Spuneți-mi cum vă simțiți", systemImage: "mic", prominence: .secondary,
                        identifier: "now.checkInButton", action: onCheckIn)
                }
            }
            .padding(Spacing.m)
        }
        .overlay { flyingCheckView }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar(moment: moment, now: now)
        }
    }

    @ViewBuilder
    private var notices: some View {
        if pinnedTime == nil {
            if !store.unseenPatientAlerts.isEmpty {
                PatientNoticeCard(caregiverName: store.patient?.caregiverName) {
                    withPgAnimation(.pgStandard) { store.markPatientAlertsSeen() }
                }
                .transition(.opacity)
            }
            if askReminders {
                ReminderAskCard(onAllow: allowReminders, onLater: declineReminders)
                    .transition(.opacity)
            }
        }
    }

    private func header(schedule: Schedule, moment: Moment?, now: Date) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TimelineDots(
                moments: schedule.moments, current: moment?.time, flying: flyingCheck, namespace: flight
            ) { log.momentStatus($0, day: schedule.date) }

            if log.lastError != nil {
                Label("Confirmarea pleacă când revine internetul.", systemImage: "arrow.clockwise.icloud")
                    .font(.system(size: textSize))
                    .foregroundStyle(PgColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("now.pendingSync")
            }

            if let moment {
                HStack(alignment: .center, spacing: Spacing.s) {
                    Text(moment.time)
                        .font(.system(size: clockSize, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(PgColor.textPrimary)
                        .accessibilityLabel("La \(SeniorDay.spokenClock(moment.time))")
                        .accessibilityIdentifier("now.clock")
                    Spacer(minLength: 0)
                    speakerButton(moment: moment, now: now)
                }
                Text(moment.label)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(PgColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("now.momentLabel")
                if let line = statusLine(moment: moment, day: schedule.date, now: now) {
                    Text(line)
                        .font(.system(size: textSize))
                        .foregroundStyle(PgColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("now.statusLine")
                }
            }
        }
    }

    private func speakerButton(moment: Moment?, now: Date) -> some View {
        Button {
            Speaker.shared.speak(speech(for: moment, now: now))
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(PgColor.accent)
                .frame(width: ControlHeight.senior, height: ControlHeight.senior)
                .background(Circle().fill(PgColor.surface))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Citește cu voce tare")
        .accessibilityIdentifier("now.speakButton")
    }

    /// Nimic de luat acum: „Ați terminat” doar dacă totul e confirmat (Q3-04).
    private func dayDone(_ schedule: Schedule) -> some View {
        let end = dayEnd(schedule)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text(SeniorDay.dayEndTitle(end))
                .font(.system(size: titleSize, weight: .semibold))
            if let tomorrow = SeniorDay.tomorrowLine(schedule.moments) {
                Text(tomorrow)
                    .font(.system(size: textSize))
            }
        }
        .foregroundStyle(PgColor.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.calmCard))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(end == .empty ? "now.empty" : "now.dayDone")
    }

    /// Eroarea se repară cu un buton mare, nu cu un gest (2.4.2, Q3-05).
    private var loadError: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Nu am putut încărca programul.")
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(PgColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("now.error")
            SeniorButton(
                "Încearcă din nou", systemImage: "arrow.clockwise", prominence: .secondary,
                identifier: "now.retryButton"
            ) {
                Task { await store.refreshAll() }
            }
        }
    }

    @ViewBuilder
    private var flyingCheckView: some View {
        if let flyingCheck {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .foregroundStyle(PgColor.accent)
                .background(Circle().fill(PgColor.onAccent).padding(Spacing.xs))
                .matchedGeometryEffect(id: CheckFlight.id(flyingCheck), in: flight)
                .frame(width: bigCheckSize, height: bigCheckSize)
                .transition(.asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity), removal: .opacity))
                .accessibilityHidden(true)
        }
    }

    // MARK: - Butoanele de jos (opace, mereu la îndemâna degetului mare)

    @ViewBuilder
    private func bottomBar(moment: Moment?, now: Date) -> some View {
        let day = store.schedule?.date ?? ""
        let showsUndo = log.undo.map { pinnedTime == nil || $0.time == pinnedTime } ?? false
        let showsButtons = moment.map { showsActions(moment: $0, now: now) } ?? false
        let showsDone = moment.map { pinnedTime != nil && log.momentStatus($0, day: day) != .open } ?? false
        // fără nimic de arătat, nici bara: altfel rămâne o cutie goală peste carduri
        if showsUndo || showsButtons || showsDone {
            VStack(spacing: Spacing.s) {
                if let undo = log.undo, showsUndo {
                    UndoBanner(status: undo.status, onUndo: undoLast)
                        .transition(.opacity)
                } else if let moment, showsButtons {
                    actionButtons(moment: moment)
                        .transition(.opacity)
                } else if let moment {
                    Label(
                        log.momentStatus(moment, day: day) == .taken ? "Le-ați luat." : "Le-ați sărit.",
                        systemImage: log.momentStatus(moment, day: day) == .taken
                            ? "checkmark.circle.fill" : "minus.circle")
                        .font(.system(size: textSize, weight: .semibold))
                        .foregroundStyle(PgColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: ControlHeight.senior)
                        .accessibilityIdentifier("now.doneLabel")
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity)
            .background(PgColor.background)
            .pgAnimation(.pgStandard, value: log.undo)
        }
    }

    /// La textul de accesibilitate, trei butoane fixe de 72 pt ar acoperi pastila (Q3-02).
    private var splitsActions: Bool { typeSize.isAccessibilitySize }

    /// Butoanele apar doar pentru un moment neconfirmat care e la ora lui, și nu cât e „Anulează” pe ecran.
    private func showsActions(moment: Moment, now: Date) -> Bool {
        guard let day = store.schedule?.date else { return false }
        if let undo = log.undo, pinnedTime == nil || undo.time == pinnedTime { return false }
        return log.momentStatus(moment, day: day) == .open
            && SeniorDay.isDue(moment, nowMinutes: SeniorDay.minutes(of: now))
    }

    private func actionButtons(moment: Moment) -> some View {
        VStack(spacing: Spacing.s) {
            SeniorButton("Am luat", systemImage: "checkmark", identifier: "now.takenButton") {
                act(.taken, moment: moment)
            }
            .accessibilityLabel("Am luat. Confirmă că ați luat \(medNames(moment)).")
            if !splitsActions {
                secondaryActions(moment: moment, vertical: false)
            }
        }
    }

    @ViewBuilder
    private func secondaryActions(moment: Moment, vertical: Bool) -> some View {
        if vertical {
            VStack(spacing: Spacing.s) {
                laterButton(moment: moment)
                skippedButton(moment: moment)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) {
                    laterButton(moment: moment)
                    skippedButton(moment: moment)
                }
                VStack(spacing: Spacing.s) {
                    laterButton(moment: moment)
                    skippedButton(moment: moment)
                }
            }
        }
    }

    private func laterButton(moment: Moment) -> some View {
        SeniorButton("Mai târziu", systemImage: "clock", prominence: .secondary, identifier: "now.laterButton") {
            snooze(moment)
        }
    }

    private func skippedButton(moment: Moment) -> some View {
        SeniorButton("Am sărit", prominence: .secondary, identifier: "now.skippedButton") {
            act(.skipped, moment: moment)
        }
    }

    // MARK: - Acțiuni

    /// Vizualul, haptica și vocea pornesc din aceeași schimbare de stare.
    private func act(_ status: DoseStatus, moment: Moment) {
        guard let schedule = store.schedule else { return }
        var recorded = false
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) {
            recorded = log.record(status, moment: moment, day: schedule.date) != nil
            if recorded && status == .taken && !reduceMotion {
                flyingCheck = moment.time
            }
        }
        guard recorded else { return }
        if status == .taken { takenCount += 1 }
        let allDone = schedule.moments.allSatisfy { log.isDone($0, day: schedule.date) }
        Speaker.shared.speak(
            SeniorDay.afterAction(status, next: nextOpen(after: moment, in: schedule), allDone: allDone))
        if flyingCheck != nil { landCheck() }
        Task { await store.rescheduleReminders() }
    }

    /// După o clipă, bifa mare se micșorează și intră în punctul momentului, care se umple.
    private func landCheck() {
        flightTask?.cancel()
        flightTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withPgAnimation(.pgMove, reduceMotion: reduceMotion) {
                flyingCheck = nil
            }
        }
    }

    /// Anularea pornește din starea de pe ecran (spring-urile se reorientează din poziția curentă).
    private func undoLast() {
        flightTask?.cancel()
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) {
            flyingCheck = nil
            log.undoLast()
        }
        Speaker.shared.stop()
        Task { await store.rescheduleReminders() }
    }

    private func snooze(_ moment: Moment) {
        guard let schedule = store.schedule,
              let until = log.snooze(moment, day: schedule.date, now: store.clock.now)
        else { return }
        Speaker.shared.speak("Bine. Vă reamintesc peste un sfert de oră.")
        let body = medNames(moment)
        Task { await Reminders.remind(at: until, title: moment.label, body: body) }
    }

    private func readOnOpen() async {
        guard pinnedTime == nil, !didAutoRead, store.settings.speakOnOpen, store.schedule != nil else { return }
        didAutoRead = true
        // după ce s-a așezat ecranul, nu peste animația de intrare
        try? await Task.sleep(for: .milliseconds(500))
        let now = store.clock.now
        Speaker.shared.speak(speech(for: displayedMoment(now: now), now: now))
    }

    private func checkReminderPermission() async {
        guard pinnedTime == nil, !store.settings.remindersAsked else { return }
        let needs = await Reminders.needsPermission()
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) { askReminders = needs }
        if !needs { store.settings.remindersAsked = true }
    }

    private func allowReminders() {
        store.settings.remindersAsked = true
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) { askReminders = false }
        Task {
            await Reminders.requestPermission()
            await store.rescheduleReminders()
        }
    }

    private func declineReminders() {
        store.settings.remindersAsked = true
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) { askReminders = false }
    }

    // MARK: - Ajutătoare

    private func displayedMoment(now: Date) -> Moment? {
        guard let schedule = store.schedule else { return nil }
        if let pinnedTime {
            return schedule.moments.first { $0.time == pinnedTime }
        }
        return SeniorDay.currentMoment(in: schedule.moments, nowMinutes: SeniorDay.minutes(of: now)) {
            log.isDone($0, day: schedule.date)
        }
    }

    /// Următorul moment neconfirmat de după cel tocmai confirmat (pentru „Următoarele pastile sunt la…”).
    private func nextOpen(after moment: Moment, in schedule: Schedule) -> Moment? {
        guard let time = SeniorDay.minutes(moment.time) else { return nil }
        return schedule.moments.first {
            (SeniorDay.minutes($0.time) ?? -1) > time && !log.isDone($0, day: schedule.date)
        }
    }

    private func statusLine(moment: Moment, day: String, now: Date) -> String? {
        let nowMinutes = SeniorDay.minutes(of: now)
        if log.momentStatus(moment, day: day) == .open, !SeniorDay.isDue(moment, nowMinutes: nowMinutes) {
            return "Pastilele acestea sunt la ora \(moment.time)."
        }
        if let until = log.snoozedUntil(moment, day: day), until > now {
            return "Vă reamintesc la ora \(PgFormat.clock(until))."
        }
        return nil
    }

    private func speech(for moment: Moment?, now: Date) -> String {
        let lines = (moment?.doses ?? []).map { dose -> String in
            let med = store.med(id: dose.medid)
            let quantity = SeniorDay.quantityWords(dose.qty, form: med?.product.form)
            return "\(med?.product.brand ?? "Un medicament"), \(quantity), \(dose.instruction)."
        }
        let due = moment.map { SeniorDay.isDue($0, nowMinutes: SeniorDay.minutes(of: now)) } ?? false
        let end = store.schedule.map { dayEnd($0) } ?? .allDone
        return SeniorDay.momentSpeech(moment, doseLines: lines, due: due, dayEnd: end)
    }

    private func dayEnd(_ schedule: Schedule) -> DayEnd {
        SeniorDay.dayEnd(schedule.moments) { log.isDone($0, day: schedule.date) }
    }

    /// „Euthyrox, Omeprazol”
    private func medNames(_ moment: Moment) -> String {
        moment.doses.map { store.med(id: $0.medid)?.product.brand ?? "medicamentul" }.joined(separator: ", ")
    }

    private var cardTransition: AnyTransition {
        PgMotion.transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)),
            reduceMotion: reduceMotion)
    }
}

/// Rotița de Setări doar pe „Acum”, nu și pe momentul deschis din „Ziua de azi”.
private struct SettingsToolbarIf: ViewModifier {
    let isOn: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content.pgSettingsToolbar()
        } else {
            content
        }
    }
}
