import Foundation
import Observation
import OSLog
import SwiftUI

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
    /// alertele la care aparținătorul a apăsat „Am înțeles” (doar pe telefon; contractul nu are rută pentru asta)
    private(set) var acknowledgedAlertIDs: Set<String> = []
    /// creat o singură dată, pentru graf (B6) și codul QR pentru medicul de familie (A6)
    private(set) var shareToken: String?
    /// ștergerea cu „Anulează” din lista de medicamente
    @ObservationIgnored private(set) var deletions = DeleteUndoQueue()
    /// „Am luat” / „Am sărit” din modul senior
    @ObservationIgnored private(set) var doseLog = DoseLog()
    /// tab-ul Noutăți al aparținătorului
    @ObservationIgnored private(set) var feed = FeedModel()

    init(settings: AppSettings = AppSettings(), debug: DebugEnvironment = .current) {
        self.settings = settings
        self.debug = debug
        clock = debug.now.map { FixedClock(now: $0) as any AppClock } ?? SystemClock()
        deletions = DeleteUndoQueue { [weak self] medID in
            try await self?.deleteMed(id: medID)
        }
        doseLog = DoseLog { [weak self] dose in
            try await self?.recordDose(dose)
        }
        feed = FeedModel(
            fetch: { [weak self] since in
                guard let self else { return [] }
                return try await self.fetchFeed(since: since)
            },
            notify: { FeedAlerts.notify($0) })
    }

    var api: APIClient {
        APIClient(baseURL: settings.baseURL, token: settings.patientToken)
    }

    func med(id: String) -> MedicationItem? {
        meds.first { $0.id == id }
    }

    func alert(id: String) -> Alert? {
        analysis?.alerts.first { $0.id == id }
    }

    /// Lista fără medicamentele șterse care încă se pot anula.
    var visibleMeds: [MedicationItem] {
        let hidden = deletions.hiddenIDs
        return hidden.isEmpty ? meds : meds.filter { !hidden.contains($0.id) }
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
        shareToken = nil
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
            shareToken = nil
            patient = created.patient
            // pacientul demo pornește de la zero: nimic confirmat, alertele de pacient din nou nevăzute
            doseLog.clear()
            feed.reset()
            settings.seenPatientAlertIDs = []
        } catch {
            Log.app.error("demo/reset a eșuat: \(String(describing: error), privacy: .public)")
            settings.signIn(patientID: AppSettings.demoPatientID, token: AppSettings.demoToken)
        }
        if didBootstrap { await refreshAll() }
    }

    func signOut() {
        deletions.cancelAll()
        doseLog.clear()
        feed.reset()
        Reminders.cancelAll()
        settings.signOut()
        patient = nil
        meds = []
        analysis = nil
        schedule = nil
        lastError = nil
        acknowledgedAlertIDs = []
        shareToken = nil
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
            doseLog.retryUnsent()
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

    /// Întoarce câte alerte noi a adus medicamentul (pentru „Am salvat. 2 alerte noi”).
    @discardableResult
    func addMed(_ med: MedicationItem) async throws -> Int {
        let id = try requirePatientID()
        let before = Set(analysis?.alerts.map(\.id) ?? [])
        let saved = try await api.addMed(patientID: id, med)
        withPgAnimation(.pgStandard) {
            meds.append(saved)
        }
        await reloadAnalysis()
        let after = Set(analysis?.alerts.map(\.id) ?? [])
        return after.subtracting(before).count
    }

    func updateMed(id medID: String, _ changes: MedicationUpdate) async throws {
        let id = try requirePatientID()
        let saved = try await api.updateMed(patientID: id, medID: medID, changes)
        if let index = meds.firstIndex(where: { $0.id == medID }) {
            withPgAnimation(.pgStandard) { meds[index] = saved }
        }
        await reloadAnalysis()
    }

    func deleteMed(id medID: String) async throws {
        let id = try requirePatientID()
        try await api.deleteMed(patientID: id, medID: medID)
        withPgAnimation(.pgStandard) {
            meds.removeAll { $0.id == medID }
        }
        await reloadAnalysis()
    }

    // MARK: - Modul senior

    func recordDose(_ dose: Dose) async throws {
        let id = try requirePatientID()
        _ = try await api.recordDose(patientID: id, dose)
    }

    /// Alertele trimise și pacientului, la care încă n-a apăsat „Am înțeles”.
    var unseenPatientAlerts: [Alert] {
        (analysis?.alerts ?? []).filter {
            $0.routeTo.contains(.patient) && !settings.seenPatientAlertIDs.contains($0.id)
        }
    }

    func markPatientAlertsSeen() {
        settings.seenPatientAlertIDs.formUnion(unseenPatientAlerts.map(\.id))
    }

    /// Reface notificările după program și confirmări (doar pe telefonul pacientului).
    func rescheduleReminders() async {
        guard settings.role == .senior, let schedule, await Reminders.isAuthorized() else { return }
        let planned = Reminders.plan(
            schedule: schedule,
            names: { self.med(id: $0)?.product.brand ?? "" },
            isDone: { self.doseLog.isDone($0, day: schedule.date) },
            now: clock.now)
        await Reminders.replaceAll(with: planned)
    }

    // MARK: - Check-in vocal și Noutăți

    func sendCheckIn(text: String) async throws -> CheckIn {
        let id = try requirePatientID()
        return try await api.createCheckIn(patientID: id, text: text)
    }

    func fetchFeed(since: Date?) async throws -> [FeedEvent] {
        let id = try requirePatientID()
        return try await api.getFeed(patientID: id, since: since)
    }

    /// Cuvintele pe care recunoașterea vocală trebuie să le știe: brandurile și substanțele pacientului,
    /// apoi cele mai frecvente branduri din catalog.
    var speechHints: [String] {
        var hints: [String] = []
        for med in meds {
            hints.append(med.product.brand)
            hints.append(contentsOf: med.substances.compactMap(\.displayName))
        }
        hints.append(contentsOf: Listener.commonBrands)
        var seen: Set<String> = []
        return hints.filter { seen.insert($0.lowercased()).inserted }
    }

    // MARK: - Alerte și partajare

    func acknowledge(alertID: String) {
        acknowledgedAlertIDs.insert(alertID)
    }

    /// Token-ul de partajare: cerut o singură dată și ținut cât e legat pacientul.
    func ensureShareToken() async throws -> String {
        if let shareToken { return shareToken }
        let id = try requirePatientID()
        let link = try await api.createShare(patientID: id)
        shareToken = link.shareToken
        return link.shareToken
    }

    #if DEBUG
    /// Doar pentru Xcode Previews: date fixe, fără server.
    func usePreviewData(patient: Patient?, meds: [MedicationItem], schedule: Schedule?, analysis: Analysis? = nil) {
        self.patient = patient
        self.meds = meds
        self.schedule = schedule
        self.analysis = analysis
        didBootstrap = true
    }
    #endif

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
