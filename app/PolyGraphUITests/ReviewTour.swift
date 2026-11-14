import XCTest

/// Turul de review: câte un test per flux, rulat în fiecare configurație din Review.xctestplan.
/// Pașii folosesc identificatorii din docs/DESIGN.md („Convenții de implementare”).
@MainActor
final class ReviewTour: ReviewTestCase {
    override class var motionTests: Set<String> {
        ["testOnboarding", "testCaregiverAlertsAndDetail", "testScanBoxFake", "testTakenAndUndo", "testDay",
         "testVoiceCheckInFake"]
    }

    private static let demoTranscript =
        "Dimineața, când mă ridic din pat, mi se învârte capul și am observat niște vânătăi pe mână."

    // MARK: - Pornirea și aparținătorul

    func testOnboarding() {
        launch("onboarding", role: nil, reset: false, defaults: ["pg.demoMode": "YES"])
        // telefonul poate fi deja legat de un pacient din testul anterior: ne deconectăm din Setări
        if !element("onboarding.role.caregiver").waitForExistence(timeout: 1) {
            if tap("settings.openButton"), let signOut = scrollTo("settings.signOutButton") {
                signOut.tap()
                tap("settings.confirmSignOutButton")
            }
        }
        guard expect("onboarding.role.caregiver", timeout: 8) != nil else { return }
        step("welcome", audit: true)
        tap("onboarding.role.caregiver")
        if let name = expect("onboarding.nameField") {
            name.tap()
            name.typeText("Maria")
        }
        step("name", audit: true)
        tap("onboarding.nextButton")
        expect("onboarding.birthYearPicker")
        step("birthYear", audit: true)
        tap("onboarding.nextButton")
        expect("onboarding.wakeTime")
        step("meals", audit: true)
        tap("onboarding.nextButton")
        expect("onboarding.bedTime")
        step("bedtime", audit: true)
        tap("onboarding.finishButton")
        if expect("tab.meds", timeout: 10) == nil { expect("onboarding.error", timeout: 1) }
        step("done", audit: true)
    }

    func testCaregiverMeds() {
        launch("caregiverMeds", role: .caregiver)
        expect("meds.list", timeout: 10)
        step("list", audit: true)
        app.swipeUp()
        step("listScrolled")
        app.swipeDown()
        guard let row = first(prefix: "meds.row.", excludingSuffix: ".alert") else {
            return markAbsent("meds.row.*")
        }
        tapElement(row)
        expect("medDetail")
        step("detail", audit: true)
        app.swipeUp()
        step("detailScrolled")
    }

    func testCaregiverAlertsAndDetail() {
        launch("caregiverAlerts", role: .caregiver)
        tapTab("Alerte")
        expect("alerts.list", timeout: 10)
        step("list", audit: true)
        app.swipeUp()
        step("listScrolled")
        app.swipeDown()
        guard let card = first(prefix: "alerts.card.") else { return markAbsent("alerts.card.*") }
        tapElement(card)
        expect("alertDetail")
        step("detail", audit: true)
        app.swipeUp()
        expect("alertDetail.source", timeout: 2)
        step("detailSource")
    }

    func testGraph() {
        launch("graph", role: .caregiver)
        tapTab("Graf")
        expect("graph.web", timeout: 10)
        // layout-ul din WKWebView se așază după primul render
        pause(2)
        step("graph", audit: true)
        if element("graph.resetButton").exists {
            tap("graph.resetButton")
            pause(1)
            step("reset")
        } else {
            markAbsent("graph.resetButton")
        }
    }

    // MARK: - Scanarea (camera falsă)

    func testScanBoxFake() {
        launch("scanBox", role: .caregiver, env: ["PG_FAKE_SCAN": "sintrom"])
        guard openScanner() else { return }
        expect("scan.fakeCamera")
        step("camera", audit: true)
        // camera falsă „citește” DataMatrix-ul după 800 ms
        pause(2)
        step("codeRead")
        tap("scan.shutter")
        guard expect("confirm.saveButton", timeout: 25) != nil else {
            expect("scan.error", timeout: 1)
            return step("noConfirm", audit: true)
        }
        step("confirm", audit: true)
        app.swipeUp()
        step("confirmScrolled")
        tap("confirm.saveButton")
        expect("meds.savedBanner", timeout: 10)
        step("saved", audit: true)
    }

    func testScanPrescriptionFake() {
        launch("scanRx", role: .caregiver, env: ["PG_FAKE_SCAN": "klacid_rx"])
        guard openScanner() else { return }
        let rx = app.buttons["Rețetă"]
        if rx.waitForExistence(timeout: 3) { rx.tap() } else { markAbsent("scan.modePicker Rețetă") }
        step("page", audit: true)
        tap("scan.fake.usePage", orLabel: "Folosește pagina")
        pause(1)
        step("reading")
        // pagina trimisă înlocuiește camera falsă; dacă butonul a rămas, atingerea n-a ajuns la el
        if app.buttons["Folosește pagina"].exists {
            markAbsent("reacția la „Folosește pagina”")
            return step("noConfirm", audit: true)
        }
        guard expect("confirm.saveButton", timeout: 30) != nil else {
            expect("scan.error", timeout: 1)
            return step("noConfirm", audit: true)
        }
        step("confirm", audit: true)
        app.swipeUp()
        step("confirmScrolled")
        tap("confirm.cancelButton")
    }

    func testScanUnreadable() {
        launch("scanUnreadable", role: .caregiver, env: ["PG_FAKE_SCAN": "unreadable"])
        guard openScanner() else { return }
        expect("scan.fakeCamera")
        step("camera")
        tap("scan.shutter")
        expect("scan.error", timeout: 25)
        step("error", audit: true)
        if tap("scan.manualButton", timeout: 2) {
            expect("confirm.saveButton", timeout: 5)
            step("manual", audit: true)
        }
    }

    private func openScanner() -> Bool {
        expect("meds.list", timeout: 10)
        if tap("meds.addButton") { return true }
        return tap("meds.emptyScanButton", timeout: 1)
    }

    // MARK: - Modul senior

    func testSeniorNowMorning() {
        seniorNow("seniorNowMorning", time: "07:05", remindersCard: true)
    }

    func testSeniorNowNoon() {
        seniorNow("seniorNowNoon", time: "13:05")
    }

    func testSeniorNowEvening() {
        seniorNow("seniorNowEvening", time: "19:05")
    }

    private func seniorNow(_ flow: String, time: String, remindersCard: Bool = false) {
        launch(flow, role: .senior, now: Self.today(at: time),
               defaults: remindersCard ? ["pg.remindersAsked": "NO"] : [:])
        expect("now.clock", timeout: 10)
        expect("now.takenButton", timeout: 3)
        step("now", audit: true)
        app.swipeUp()
        step("nowScrolled")
    }

    func testTakenAndUndo() {
        launch("takenUndo", role: .senior, now: Self.today(at: "07:05"))
        guard expect("now.takenButton", timeout: 10) != nil else { return step("noDose", audit: true) }
        step("before")
        timedTap("now.takenButton")
        // cadrele animației vin din video (frames/); aici, starea de după
        pause(1)
        expect("now.undoBanner", timeout: 3)
        // bannerul „Anulează” dispare după câteva secunde: auditul vine după
        step("taken")
        tap("now.undoButton")
        pause(1)
        expect("now.takenButton", timeout: 3)
        step("undone", audit: true)
    }

    func testDay() {
        launch("day", role: .senior, now: Self.today(at: "13:05"))
        guard tap("now.dayButton", timeout: 10) else { return }
        expect("day.moment.07:00")
        step("day", audit: true)
        app.swipeUp()
        step("dayScrolled")
        app.swipeDown()
        if let moment = first(prefix: "day.moment.") {
            tapElement(moment)
            expect("now.momentLabel")
            step("moment", audit: true)
        } else {
            markAbsent("day.moment.*")
        }
    }

    func testVoiceCheckInFake() {
        launch("voiceCheckIn", role: .senior, now: Self.today(at: "08:30"),
               env: ["PG_FAKE_TRANSCRIPT": Self.demoTranscript])
        guard tap("now.checkInButton", timeout: 10) else { return }
        expect("checkin.micButton")
        step("ready", audit: true)
        timedTap("checkin.micButton")
        pause(0.8)
        step("listening")
        pause(1.5)
        step("transcript")
        expect("checkin.reply", timeout: 30)
        step("reply", audit: true)
        tap("checkin.doneButton", timeout: 2)
        step("afterDone")
    }

    // MARK: - Noutăți, medicul, setările

    func testFeed() {
        launch("feed", role: .caregiver)
        tapTab("Noutăți")
        expect("feed.list", timeout: 10)
        step("feed", audit: true)
        guard let event = first(prefix: "feed.event.") else { return markAbsent("feed.event.*") }
        tapElement(event)
        pause(1)
        step("event", audit: true)
    }

    func testShare() {
        launch("shareCaregiver", role: .caregiver)
        expect("meds.list", timeout: 10)
        if tap("meds.shareButton") {
            expect("share.qr", timeout: 10)
            step("caregiver", audit: true)
            tap("share.doneButton")
        }
        // același cod, deschis de pacient din „Ziua de azi”
        app.terminate()
        launch("shareSenior", role: .senior, now: Self.today(at: "13:05"))
        guard tap("now.dayButton", timeout: 10) else { return }
        if tap("day.shareButton") {
            expect("share.qr", timeout: 10)
            step("senior", audit: true)
            tap("share.doneButton")
        }
    }

    func testSettingsDemo() {
        launch("settings", role: .caregiver, defaults: ["pg.demoMode": "YES"])
        expect("meds.list", timeout: 10)
        guard tap("settings.openButton") else { return }
        expect("settings.baseURLField")
        step("settings", audit: true)
        tap("settings.checkConnectionButton")
        expect("settings.connectionStatus", timeout: 5)
        step("connection")
        if let rx = scrollTo("settings.addRxButton") {
            rx.tap()
            expect("settings.demoStatus", timeout: 10)
            step("demoRx", audit: true)
        }
        app.swipeUp()
        step("settingsScrolled")
        tap("settings.doneButton")
    }

    // MARK: - Stări limită

    func testBackendDown() {
        // portul 9 (discard) e închis pe orice Mac: fiecare cerere pică imediat
        let down = ["PG_BASE_URL": "http://127.0.0.1:9"]
        launch("backendDownCaregiver", role: .caregiver, reset: false, env: down)
        expect("meds.error", timeout: 15)
        step("meds", audit: true)
        tapTab("Alerte")
        expect("alerts.error", timeout: 10)
        step("alerts")
        app.terminate()
        launch("backendDownSenior", role: .senior, reset: false, now: Self.today(at: "07:05"), env: down)
        expect("now.error", timeout: 15)
        step("now", audit: true)
    }
}
