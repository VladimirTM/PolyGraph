import SwiftUI
import OSLog

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var connectionStatus: String?
    @State private var isChecking = false
    @State private var isResettingDemo = false
    @State private var confirmSignOut = false

    var body: some View {
        @Bindable var settings = store.settings

        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.10:8000", text: $baseURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(saveBaseURL)
                        .accessibilityLabel("Adresa serverului")
                        .accessibilityIdentifier("settings.baseURLField")
                    Button {
                        Task { await checkConnection() }
                    } label: {
                        HStack {
                            Text("Verifică legătura")
                            Spacer()
                            if isChecking { ProgressView() }
                        }
                    }
                    .disabled(isChecking)
                    .accessibilityIdentifier("settings.checkConnectionButton")
                    if let connectionStatus {
                        Text(connectionStatus)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings.connectionStatus")
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Pe telefon: adresa Mac-ului din aceeași rețea Wi-Fi, cu portul 8000. Pe simulator: http://127.0.0.1:8000.")
                }

                Section {
                    Picker("Cine folosește telefonul", selection: $settings.role) {
                        ForEach(AppRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.rolePicker")
                } header: {
                    Text("Cine folosește telefonul")
                } footer: {
                    Text("Pacient: un singur ecran, cu butoane mari. Aparținător: lista, alertele, graful și noutățile.")
                }

                Section {
                    Toggle("Mod demo", isOn: $settings.demoMode)
                        .accessibilityIdentifier("settings.demoModeToggle")
                    if settings.demoMode {
                        Button {
                            Task { await useDemoPatient() }
                        } label: {
                            HStack {
                                Text("Folosește pacientul demo")
                                Spacer()
                                if isResettingDemo { ProgressView() }
                            }
                        }
                        .disabled(isResettingDemo)
                        .accessibilityIdentifier("settings.useDemoPatientButton")
                    }
                } footer: {
                    Text("Pacientul demo e refăcut pe server cu lista inițială de medicamente.")
                }

                if settings.isSignedIn {
                    Section("Pacient") {
                        if let patient = store.patient {
                            LabeledContent("Nume", value: patient.name)
                            LabeledContent("Anul nașterii", value: String(patient.birthYear))
                        }
                        Button("Deconectează telefonul", role: .destructive) {
                            confirmSignOut = true
                        }
                        .accessibilityIdentifier("settings.signOutButton")
                    }
                }
            }
            .navigationTitle("Setări")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") {
                        saveBaseURL()
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.doneButton")
                }
            }
            .confirmationDialog(
                "Deconectați telefonul?",
                isPresented: $confirmSignOut,
                titleVisibility: .visible
            ) {
                Button("Deconectează", role: .destructive) {
                    store.signOut()
                    dismiss()
                }
                .accessibilityIdentifier("settings.confirmSignOutButton")
            } message: {
                Text("Datele rămân pe server. Telefonul va porni din nou de la început.")
            }
        }
        .onAppear { baseURL = store.settings.baseURLString }
    }

    private func saveBaseURL() {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != store.settings.baseURLString else { return }
        store.settings.baseURLString = trimmed
        Log.settings.info("baseURL = \(trimmed, privacy: .public)")
    }

    private func checkConnection() async {
        saveBaseURL()
        isChecking = true
        defer { isChecking = false }
        do {
            let status = try await APIClient(baseURL: store.settings.baseURL, token: nil).health()
            connectionStatus = status.ok
                ? "Serverul răspunde\(status.mode.map { " (\($0))" } ?? "")."
                : "Serverul răspunde, dar nu e pregătit."
        } catch {
            connectionStatus = (error as? LocalizedError)?.errorDescription ?? "Nu pot ajunge la server."
        }
    }

    private func useDemoPatient() async {
        saveBaseURL()
        isResettingDemo = true
        defer { isResettingDemo = false }
        await store.useDemoPatient()
    }
}

private struct SettingsToolbar: ViewModifier {
    @Environment(AppStore.self) private var store
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = true
                    } label: {
                        Label("Setări", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settings.openButton")
                }
            }
            .sheet(isPresented: $isPresented) {
                SettingsView()
                    .environment(store)
            }
    }
}

extension View {
    /// Butonul de Setări din bara de navigare (rotița), cu foaia de setări.
    func pgSettingsToolbar() -> some View {
        modifier(SettingsToolbar())
    }
}
