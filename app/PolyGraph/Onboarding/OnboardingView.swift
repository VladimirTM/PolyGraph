import SwiftUI
import OSLog

/// Un pas pe ecran, butonul principal jos, progresul („Pasul 2 din 4”) sus. La final: POST /v1/patients.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, name, birthYear, meals, bedtime

        /// pașii numărați în „Pasul n din 4” (primul ecran, alegerea rolului, nu se numără)
        static let countedSteps = 4
    }

    @Environment(AppStore.self) private var store
    @Environment(\.pgReduceMotion) private var reduceMotion

    @State private var step: Step = .welcome
    @State private var movingForward = true
    @State private var role: AppRole = .senior
    @State private var name = ""
    @State private var birthYear = 1948
    @State private var wake = PgFormat.date(fromClock: "07:00") ?? .now
    @State private var breakfast = PgFormat.date(fromClock: "08:00") ?? .now
    @State private var lunch = PgFormat.date(fromClock: "13:00") ?? .now
    @State private var dinner = PgFormat.date(fromClock: "19:00") ?? .now
    @State private var bedtime = PgFormat.date(fromClock: "22:00") ?? .now
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var settingsPresented = false
    @FocusState private var nameFocused: Bool

    @ScaledMetric(relativeTo: .title2) private var fieldSize: CGFloat = 22
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step != .welcome {
                    progressHeader
                }
                // la mărimile de accesibilitate butoanele intră în scroll, după întrebare: fixate jos, o acopereau (Q3-22)
                ScrollView {
                    stepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.m)
                        .id(step)
                        .transition(stepTransition)
                    if dynamicTypeSize.isAccessibilitySize {
                        bottomBar
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                if !dynamicTypeSize.isAccessibilitySize {
                    bottomBar
                }
            }
            .background(PgColor.background)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            go(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
                        } label: {
                            Label("Înapoi", systemImage: "chevron.backward")
                                .labelStyle(.titleAndIcon)
                        }
                        .accessibilityIdentifier("onboarding.backButton")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settingsPresented = true
                    } label: {
                        Label("Setări", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settings.openButton")
                }
            }
            .sheet(isPresented: $settingsPresented) {
                SettingsView()
                    .environment(store)
            }
            .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
        }
    }

    // MARK: - Părți

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Pasul \(step.rawValue) din \(Step.countedSteps)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PgColor.textSecondary)
            ProgressView(value: Double(step.rawValue), total: Double(Step.countedSteps))
                .tint(PgColor.accent)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.top, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.progress")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .name: nameStep
        case .birthYear: birthYearStep
        case .meals: mealsStep
        case .bedtime: bedtimeStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(PgColor.accent)
                .accessibilityHidden(true)
            Text("Bun venit")
                .font(.largeTitle.bold())
                .foregroundStyle(PgColor.textPrimary)
            Text("PolyGraph vă arată ce medicamente se iau, când și ce nu merge împreună.")
                .font(.title3)
                .foregroundStyle(PgColor.textSecondary)
            Text("Pentru cine folosiți telefonul?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PgColor.textPrimary)
                .padding(.top, Spacing.m)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            stepTitle(forRole("Cum vă numiți?", "Cum se numește persoana de care aveți grijă?"))
            TextField("Prenumele", text: $name)
                .font(.system(size: fieldSize))
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($nameFocused)
                .onSubmit { if canContinue { advance() } }
                .padding(Spacing.m)
                .frame(minHeight: ControlHeight.senior)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(PgColor.surface))
                .accessibilityIdentifier("onboarding.nameField")
            Text("Numele apare în mesajele aplicației.")
                .font(.body)
                .foregroundStyle(PgColor.textSecondary)
        }
        .onAppear { nameFocused = true }
    }

    private var birthYearStep: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            stepTitle(forRole("În ce an v-ați născut?", "În ce an s-a născut?"))
            Text("Unele medicamente au alte reguli după 65 de ani.")
                .font(.body)
                .foregroundStyle(PgColor.textSecondary)
            Picker("Anul nașterii", selection: $birthYear) {
                ForEach(Array((1920...2008).reversed()), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityIdentifier("onboarding.birthYearPicker")
        }
    }

    private var mealsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            stepTitle(forRole("Când vă treziți și când mâncați?", "Când se trezește și când mănâncă?"))
            Text("Potrivim orele medicamentelor după ziua obișnuită.")
                .font(.body)
                .foregroundStyle(PgColor.textSecondary)
            TimeRow(title: "Trezirea", selection: $wake, identifier: "onboarding.wakeTime")
            TimeRow(title: "Micul dejun", selection: $breakfast, identifier: "onboarding.breakfastTime")
            TimeRow(title: "Prânzul", selection: $lunch, identifier: "onboarding.lunchTime")
            TimeRow(title: "Cina", selection: $dinner, identifier: "onboarding.dinnerTime")
        }
    }

    private var bedtimeStep: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            stepTitle(forRole("Când vă culcați?", "Când se culcă?"))
            DatePicker("Culcarea", selection: $bedtime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, PgFormat.romanian)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("onboarding.bedTime")
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.s) {
            if let errorMessage {
                Label(errorMessage, systemImage: "wifi.exclamationmark")
                    .font(.body)
                    .foregroundStyle(PgColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("onboarding.error")
            }
            switch step {
            case .welcome:
                SeniorButton("Pentru mine", systemImage: "person", identifier: "onboarding.role.senior") {
                    role = .senior
                    advance()
                }
                SeniorButton(
                    "Pentru cineva drag", systemImage: "person.2", prominence: .secondary,
                    identifier: "onboarding.role.caregiver"
                ) {
                    role = .caregiver
                    advance()
                }
                if store.settings.demoMode {
                    Button("Folosește pacientul demo") {
                        Task { await store.useDemoPatient() }
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding.demoButton")
                }
            case .bedtime:
                SeniorButton(isSubmitting ? "Se salvează…" : "Gata", identifier: "onboarding.finishButton") {
                    Task { await submit() }
                }
                .disabled(isSubmitting)
            default:
                SeniorButton("Continuă", identifier: "onboarding.nextButton") {
                    advance()
                }
                .disabled(!canContinue)
            }
        }
        .padding(Spacing.m)
        .background(PgColor.background)
    }

    // MARK: - Logică

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        step != .name || !trimmedName.isEmpty
    }

    private var stepTransition: AnyTransition {
        let spatial: AnyTransition = .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity))
        return PgMotion.transition(spatial, reduceMotion: reduceMotion)
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        go(to: next)
    }

    private func go(to target: Step) {
        movingForward = target.rawValue > step.rawValue
        errorMessage = nil
        withPgAnimation(.pgStandard, reduceMotion: reduceMotion) {
            step = target
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let anchors = Anchors(
            bed: PgFormat.clock(bedtime),
            breakfast: PgFormat.clock(breakfast),
            dinner: PgFormat.clock(dinner),
            lunch: PgFormat.clock(lunch),
            wake: PgFormat.clock(wake))
        let body = PatientCreate(anchors: anchors, birthYear: birthYear, caregiverName: nil, name: trimmedName)
        do {
            try await store.createPatient(body, role: role)
        } catch {
            Log.onboarding.error("createPatient: \(String(describing: error), privacy: .public)")
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Nu am putut salva. Încercați din nou."
        }
    }

    private func forRole(_ senior: String, _ caregiver: String) -> String {
        role == .senior ? senior : caregiver
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle.bold())
            .foregroundStyle(PgColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Un rând „Micul dejun · 08:00”; la atingere se deschide roata de sub el (tiparul din Calendar).
private struct TimeRow: View {
    let title: String
    @Binding var selection: Date
    let identifier: String

    @State private var expanded = false
    @Environment(\.pgReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var fontSize: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withPgAnimation(.pgStandard, reduceMotion: reduceMotion) { expanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(PgColor.textPrimary)
                    Spacer()
                    Text(PgFormat.clock(selection))
                        .monospacedDigit()
                        .foregroundStyle(PgColor.accent)
                }
                .font(.system(size: fontSize, weight: .semibold))
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: ControlHeight.senior)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("\(title), ora \(PgFormat.clock(selection))")
            .accessibilityHint(expanded ? "Atingeți ca să închideți" : "Atingeți ca să schimbați ora")
            .accessibilityIdentifier(identifier)

            if expanded {
                DatePicker(title, selection: $selection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, PgFormat.romanian)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("\(identifier).picker")
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(PgColor.surface))
    }
}
