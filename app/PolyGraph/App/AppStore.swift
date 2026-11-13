import Foundation
import Observation
import OSLog

/// Starea comună a aplicației: pacientul, medicamentele, analiza și programul zilei.
/// Orice schimbare a listei de medicamente reîncarcă analiza și programul.
@Observable
final class AppStore {
    let settings: AppSettings
    let clock: any AppClock
    @ObservationIgnored private let debug: DebugEnvironment

    private(set) var patient: Patient?
    private(set) var meds: [MedicationItem] = []
    private(set) var analysis: Analysis?
    private(set) var schedule: Schedule?
    private(set) var isLoading = false
    private(set) var didBootstrap = false
    /// ultimul mesaj de eroare, în română, afișabil
    var lastError: String?

    init(settings: AppSettings = AppSettings(), debug: DebugEnvironment = .current) {
        self.settings = settings
        self.debug = debug
        clock = debug.now.map { FixedClock(now: $0) as any AppClock } ?? SystemClock()
    }

    var api: APIClient {
        APIClient(baseURL: settings.baseURL, token: settings.patientToken)
    }

    func med(id: String) -> MedicationItem? {
        meds.first { $0.id == id }
    }

    // MARK: - Pornire

    func bootstrap() async {
        guard !didBootstrap else { return }
        applyDebugOverrides()
        if debug.resetDemo {
            await useDemoPatient()
        }
        didBootstrap = true
        if settings.isSignedIn {
            await refreshAll()
        }
    }

    private func applyDebugOverrides() {
        if let baseURL = debug.baseURL { settings.baseURLString = baseURL }
        if let role = debug.role { settings.role = role }
        if debug.skipOnboarding && !settings.isSignedIn {
            settings.signIn(patientID: AppSettings.demoPatientID, token: AppSettings.demoToken)
        }
    }

    // MARK: - Pacientul

    func createPatient(_ body: PatientCreate, role: AppRole) async throws {
        let created = try await api.createPatient(body)
        settings.role = role
        settings.signIn(patientID: created.id, token: created.patientToken)
        patient = created.patient
        Log.app.info("Pacient creat: \(created.id, privacy: .public)")
        await refreshAll()
    }

    /// Pacientul demo, recreat pe server din fixture. Dacă serverul nu are modul demo,
    /// telefonul se leagă oricum de `pat_demo` (mock-ul îl are mereu).
    func useDemoPatient(liveScan: Bool = false) async {
        do {
            let created = try await api.demoReset(liveScan: liveScan)
            settings.signIn(patientID: created.id, token: created.patientToken)
            patient = created.patient
        } catch {
            Log.app.error("demo/reset a eșuat: \(String(describing: error), privacy: .public)")
            settings.signIn(patientID: AppSettings.demoPatientID, token: AppSettings.demoToken)
        }
        if didBootstrap { await refreshAll() }
    }

    func signOut() {
        settings.signOut()
        patient = nil
        meds = []
        analysis = nil
        schedule = nil
        lastError = nil
    }

    // MARK: - Încărcare

    func refreshAll() async {
        guard let id = settings.patientID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            patient = try await api.getPatient(id: id)
            meds = try await api.listMeds(patientID: id)
            analysis = try await api.getAnalysis(patientID: id)
            schedule = try await api.getSchedule(patientID: id, date: scheduleDate)
            lastError = nil
        } catch {
            report(error)
        }
    }

    func reloadAnalysis() async {
        guard let id = settings.patientID else { return }
        do {
            analysis = try await api.getAnalysis(patientID: id)
            schedule = try await api.getSchedule(patientID: id, date: scheduleDate)
        } catch {
            report(error)
        }
    }

    // MARK: - Medicamente

    func addMed(_ med: MedicationItem) async throws {
        let id = try requirePatientID()
        let saved = try await api.addMed(patientID: id, med)
        meds.append(saved)
        await reloadAnalysis()
    }

    func updateMed(id medID: String, _ changes: MedicationUpdate) async throws {
        let id = try requirePatientID()
        let saved = try await api.updateMed(patientID: id, medID: medID, changes)
        if let index = meds.firstIndex(where: { $0.id == medID }) { meds[index] = saved }
        await reloadAnalysis()
    }

    func deleteMed(id medID: String) async throws {
        let id = try requirePatientID()
        try await api.deleteMed(patientID: id, medID: medID)
        meds.removeAll { $0.id == medID }
        await reloadAnalysis()
    }

    // MARK: - Ajutătoare

    /// Cu `PG_NOW`, programul cerut e al zilei fixate; altfel serverul alege „azi” (ora României).
    private var scheduleDate: String? {
        debug.now.map(PgFormat.isoDay)
    }

    private func requirePatientID() throws -> String {
        guard let id = settings.patientID else { throw APIError.missingToken }
        return id
    }

    private func report(_ error: Error) {
        lastError = (error as? LocalizedError)?.errorDescription ?? "A apărut o eroare neașteptată."
        Log.app.error("\(String(describing: error), privacy: .public)")
    }
}
