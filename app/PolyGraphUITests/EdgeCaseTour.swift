import XCTest

/// Turul agresiv (Q3): apăsări repetate, anulări la limită, scanări ciudate, ore la marginea zilei,
/// backend oprit în timpul fluxului, check-in-uri limită, multe Noutăți, accesibilitate dură.
/// Rulează cu infrastructura turului de review: `make review Q=Q3e TOUR=EdgeCaseTour CONFIGS="Light AX" NO_VIDEO=1`.
/// Ca `ReviewTour`, testele nu pică: ce nu apare e notat „absent”, iar judecata se face din capturi și JSON.
@MainActor
final class EdgeCaseTour: ReviewTestCase {
    // MARK: - Ajutătoare

    /// Apăsări rapide pe același punct (2–5 în < 300 ms): XCUITest le trimite ca un singur gest cu mai multe atingeri.
    private func burst(_ identifier: String, taps: Int) {
        guard let target = expect(identifier, timeout: 10) else { return }
        let deadline = Date().addingTimeInterval(3)
        while target.frame.isEmpty && Date() < deadline { pause(0.2) }
        target.tap(withNumberOfTaps: taps, numberOfTouches: 1)
    }

    /// Cereri directe la backend-ul turului (din runner), ca pacientul demo să primească date înainte de capturi.
    @discardableResult
    private func api(_ method: String, _ path: String, json: Any? = nil) -> (Int, Data) {
        var request = URLRequest(url: URL(string: Self.baseURL + path)!)
        request.httpMethod = method
        request.setValue("demo-token", forHTTPHeaderField: "X-Patient-Token")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: (Int, Data) = (0, Data())
        URLSession.shared.dataTask(with: request) { data, response, _ in
            result = ((response as? HTTPURLResponse)?.statusCode ?? 0, data ?? Data())
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 30)
        return result
    }

    private func setBaseURL(_ url: String) {
        guard tap("settings.openButton") else { return }
        guard let field = expect("settings.baseURLField") else { return }
        field.tap()
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 5))
        }
        field.typeText(url)
        tap("settings.checkConnectionButton")
        expect("settings.connectionStatus", timeout: 8)
        step("settings-\(url.hasSuffix(":9") ? "down" : "up")")
        tap("settings.doneButton")
    }

    private func deleteRow(_ row: XCUIElement, id: String) {
        row.swipeLeft()
        let button = element("meds.deleteButton.\(id)")
        if button.waitForExistence(timeout: 1) { button.tap() }
    }

    // MARK: - Apăsări repetate (modul senior)

    func testRapidTaken() {
        launch("rapidTaken", role: .senior, now: Self.today(at: "07:05"))
        expect("now.takenButton", timeout: 10)
        step("before")
        burst("now.takenButton", taps: 2)
        pause(0.5)
        step("afterDoubleTap", audit: true)
        // a doua apăsare putea ateriza pe „Anulează”, care ia locul butonului
        if element("now.undoBanner").exists {
            burst("now.undoButton", taps: 3)
            pause(0.8)
            step("afterTripleUndo")
        }
        burst("now.takenButton", taps: 5)
        pause(0.8)
        step("afterFiveTaps")
    }

    func testRapidLaterAndSkipped() {
        launch("rapidLater", role: .senior, now: Self.today(at: "13:05"))
        burst("now.laterButton", taps: 3)
        pause(0.8)
        step("afterLater", audit: true)
        burst("now.skippedButton", taps: 3)
        pause(0.8)
        // Q3-03: atingerile 2 și 3 cad pe „Anulează” abia apărut și sunt ignorate
        expect("now.undoBanner", timeout: 2)
        step("afterSkipped")
    }

    func testTakenUndoTakenAndExpiry() {
        launch("undoCycle", role: .senior, now: Self.today(at: "07:05"))
        tap("now.takenButton", timeout: 10)
        // „Anulează” ignoră atingerile din primele 800 ms (Q3-03)
        pause(1)
        tap("now.undoButton", timeout: 3)
        pause(0.6)
        step("undone")
        // la 1 s după, al doilea „Am luat” nu e blocat de gardă
        pause(1.2)
        tap("now.takenButton", timeout: 3)
        pause(0.5)
        step("takenAgain")
        // după 5 s „Anulează” trebuie să fi dispărut
        pause(6)
        step("afterUndoWindow", audit: true)
        if element("now.undoButton").exists {
            tap("now.undoButton")
            step("lateUndo")
        }
    }

    // MARK: - Medicamente: ștergere, anulare, totul șters

    func testDeleteUndoAndDeleteAll() {
        launch("deleteAll", role: .caregiver)
        expect("meds.list", timeout: 10)
        // Sintrom (med_01) din fixture, dacă e în listă: T-Q3F6-02 verifică că „Anulează” îl readuce
        let sintrom = element("meds.row.med_01")
        guard let row = sintrom.waitForExistence(timeout: 5)
            ? Optional(sintrom) : first(prefix: "meds.row.", excludingSuffix: ".alert")
        else { return markAbsent("meds.row.*") }
        let id = String(row.identifier.dropFirst("meds.row.".count))
        deleteRow(row, id: id)
        expect("meds.undoBanner", timeout: 3)
        // fără audit aici: durează câteva secunde, iar „Anulează” trebuie atins în fereastra de 5 s
        step("deleted")
        burst("meds.undoButton", taps: 3)
        pause(0.8)
        expect("meds.row.\(id)", timeout: 3)
        step("undone", audit: true)
        if let again = first(prefix: "meds.row.\(id)", excludingSuffix: ".alert") { deleteRow(again, id: id) }
        pause(0.5)
        step("deletedAgain")
        // toate celelalte, una după alta (fiecare ștergere o confirmă pe cea dinainte)
        for _ in 0..<12 {
            guard let next = first(prefix: "meds.row.", excludingSuffix: ".alert") else { break }
            deleteRow(next, id: String(next.identifier.dropFirst("meds.row.".count)))
            pause(0.4)
        }
        pause(6.5)
        expect("meds.empty", timeout: 5)
        step("emptyMeds", audit: true)
        tapTab("Alerte")
        pause(1.5)
        step("emptyAlerts", audit: true)
        tapTab("Graf")
        pause(2.5)
        step("emptyGraph", audit: true)
        tapTab("Noutăți")
        pause(1.5)
        step("emptyFeed")
        app.terminate()
        launch("deleteAllSenior", role: .senior, reset: false, now: Self.today(at: "07:05"))
        pause(2)
        expect("now.empty", timeout: 5)
        step("emptyNow", audit: true)
        if tap("now.dayButton", timeout: 5) {
            pause(1)
            expect("day.empty", timeout: 3)
            step("emptyDay", audit: true)
        }
    }

    // MARK: - Modul demo

    func testRapidDemoButtons() {
        launch("rapidDemo", role: .caregiver, defaults: ["pg.demoMode": "YES"])
        expect("meds.list", timeout: 10)
        guard tap("settings.openButton") else { return }
        if scrollTo("settings.addRxButton") != nil {
            burst("settings.addRxButton", taps: 4)
            pause(4)
            step("rxBurst", audit: true)
            burst("settings.missedDoseButton", taps: 3)
            pause(3)
            step("missedBurst")
        }
        if scrollTo("settings.useDemoPatientButton") != nil {
            burst("settings.useDemoPatientButton", taps: 3)
            pause(4)
            step("resetBurst")
        }
        tap("settings.doneButton")
        pause(1)
        app.swipeUp()
        step("medsAfter")
        tapTab("Noutăți")
        pause(2)
        step("feedAfter")
    }

    // MARK: - Scanări

    private func scan(_ name: String, flow: String, prescription: Bool = false, reset: Bool = true) {
        launch(flow, role: .caregiver, reset: reset, env: ["PG_FAKE_SCAN": name])
        expect("meds.list", timeout: 10)
        guard tap("meds.addButton") || tap("meds.emptyScanButton", timeout: 1) else { return }
        if prescription {
            let rx = app.buttons["Rețetă"]
            if rx.waitForExistence(timeout: 3) { rx.tap() }
            tapFakeUsePage()
        } else {
            pause(2)
            tap("scan.shutter")
        }
        if expect("confirm.saveButton", timeout: 30) == nil { expect("scan.error", timeout: 1) }
        step("result", audit: true)
    }

    func testScanVariants() {
        for name in ["nurofen", "expired", "aspirin"] {
            scan(name, flow: "scan-\(name)")
            app.swipeUp()
            step("scrolled")
            app.terminate()
        }
    }

    func testScanSameBoxTwice() {
        scan("sintrom", flow: "scanTwice")
        tap("confirm.saveButton")
        expect("meds.savedBanner", timeout: 10)
        step("firstSaved")
        guard tap("meds.addButton") else { return }
        pause(2)
        tap("scan.shutter")
        expect("confirm.saveButton", timeout: 30)
        step("second", audit: true)
        burst("confirm.saveButton", taps: 3)
        pause(3)
        step("secondSavedBurst")
        app.swipeUp()
        step("listAfter")
    }

    /// Rețeta cu trei medicamente: pagina falsă e textul numelui, cu rânduri noi.
    func testScanMultiPrescription() {
        scan("Aspirin 500 mg\nParacetamol 500 mg\nAlgocalmin 500 mg", flow: "scanMulti", prescription: true)
        tap("confirm.skipButton", timeout: 2)
        pause(0.8)
        step("second")
        tap("confirm.cancelButton")
        pause(1)
        step("cancelHalf")
    }

    func testConfirmFieldLimits() {
        scan("sintrom", flow: "confirmFields")
        guard let brand = expect("confirm.brandField") else { return }
        let values = [
            ("empty", ""),
            ("oneChar", "S"),
            ("long", String(repeating: "Sintrom ", count: 15)),
            ("emoji", "Sintrom 💊😀"),
            ("diacritics", "Ăâîșț ĂÂÎȘȚ"),
        ]
        for (label, value) in values {
            brand.tap()
            if let current = brand.value as? String {
                brand.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
            }
            brand.typeText(value)
            step("brand-\(label)")
        }
        if let strength = expect("confirm.strengthField") {
            for value in ["0 mg", "-5 mg", "9999 mg"] {
                strength.tap()
                if let current = strength.value as? String {
                    strength.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
                }
                strength.typeText(value)
                step("strength-\(value.replacingOccurrences(of: " ", with: ""))")
            }
        }
        // posologia e din steppere 0–4: apăsăm „+” de 12 ori pe dimineață
        if let stepper = scrollTo("confirm.dose.morning") {
            let plus = stepper.buttons.element(boundBy: 1)
            for _ in 0..<12 where plus.exists { plus.tap() }
            step("doseMax", audit: true)
        }
        tap("confirm.saveButton")
        pause(3)
        step("saved")
    }

    // MARK: - Timpul

    func testClockEdges() {
        let times: [(String, String)] = [
            ("midnight", Self.today(at: "00:00")),
            ("three", Self.today(at: "03:00")),
            ("exact1300", Self.today(at: "13:00")),
            ("lateNight", Self.today(at: "23:59")),
            ("dstSpring", "2026-03-29T03:30:00"),
            ("dstAutumn", "2026-10-25T04:00:00"),
            ("nextYear", "2027-11-14T08:00:00"),
        ]
        for (label, now) in times {
            launch("clock-\(label)", role: .senior, now: now)
            expect("now.clock", timeout: 10)
            step("now", audit: label == "lateNight")
            app.terminate()
        }
        launch("clock-yearCaregiver", role: .caregiver, now: "2027-11-14T08:00:00")
        tapTab("Alerte")
        pause(2)
        step("alerts")
    }

    func testUnconfirmedDayAtNight() {
        // nimic confirmat azi, iar seara târziu: ce vede pacientul?
        launch("nightUnconfirmed", role: .senior, now: Self.today(at: "23:30"))
        pause(2)
        step("now", audit: true)
        if tap("now.dayButton", timeout: 5) {
            pause(1)
            step("day")
        }
    }

    // MARK: - Rețeaua

    func testBackendDropsMidFlowCaregiver() {
        launch("netCaregiver", role: .caregiver)
        expect("meds.list", timeout: 10)
        step("online")
        setBaseURL("http://127.0.0.1:9")
        app.swipeDown()
        pause(2)
        step("medsOffline", audit: true)
        tapTab("Graf")
        pause(3)
        step("graphOffline")
        tapTab("Noutăți")
        pause(2)
        app.swipeDown()
        pause(2)
        step("feedOffline")
        tapTab("Medicamente")
        if tap("meds.addButton", timeout: 2) {
            pause(1)
            step("scanOffline")
            tap("scan.closeButton", timeout: 2)
        }
        setBaseURL(Self.baseURL)
        pause(1)
        step("backOnline")
        tap("meds.retryButton", timeout: 2)
        pause(3)
        step("recovered", audit: true)
        tapTab("Graf")
        pause(3)
        step("graphRecovered")
    }

    func testBackendDropsMidFlowSenior() {
        launch("netSenior", role: .senior, now: Self.today(at: "07:05"))
        expect("now.takenButton", timeout: 10)
        setBaseURL("http://127.0.0.1:9")
        tap("now.takenButton")
        pause(1)
        // Q3-07: confirmarea rămâne de trimis și se spune, calm
        expect("now.pendingSync", timeout: 5)
        step("takenOffline", audit: true)
        pause(6)
        step("afterUndoWindowOffline")
        if tap("now.checkInButton", timeout: 3) {
            app.swipeUp()
            step("checkinOffline")
            app.navigationBars.buttons.firstMatch.tap()
        }
        setBaseURL(Self.baseURL)
        app.swipeDown()
        pause(3)
        if element("now.pendingSync").exists { markAbsent("now.pendingSync dispărut după revenire") }
        step("recovered")
    }

    func testBackendDownSeniorScreens() {
        let down = ["PG_BASE_URL": "http://127.0.0.1:9"]
        launch("downSenior", role: .senior, reset: false, now: Self.today(at: "07:05"), env: down)
        pause(4)
        // Q3-05: eroarea se repară cu un buton, nu cu un gest
        expect("now.retryButton", timeout: 3)
        step("now")
        if tap("now.dayButton", timeout: 3) {
            pause(2)
            expect("day.retryButton", timeout: 3)
            step("day", audit: true)
            tap("day.backButton", timeout: 3)
        }
        if tap("now.checkInButton", timeout: 3) {
            step("checkin")
        }
        app.terminate()
        launch("downCaregiver", role: .caregiver, reset: false, env: down)
        tapTab("Graf")
        pause(4)
        step("graph", audit: true)
        tapTab("Noutăți")
        pause(4)
        step("feed", audit: true)
        tapTab("Medicamente")
        if tap("meds.shareButton", timeout: 3) {
            pause(3)
            step("share", audit: true)
        }
    }

    // MARK: - Check-in vocal

    private static let transcripts: [(String, String)] = [
        ("blank", "   "),
        ("oneWord", "bine"),
        ("long", String(repeating: "Mă doare puțin capul și sunt obosită de câteva zile. ", count: 12)),
        ("chestPain", "Am o durere în piept de azi dimineață."),
        ("many", "Am amețeli, greață, mă dor mușchii și am vânătăi pe mâini și scaun negru."),
        ("english", "I feel dizzy and I have a headache."),
        ("sindrom", "Pot să iau sindromul seara cu mâncare?"),
        ("negated", "Nu am amețeli și nu mă doare nimic."),
        ("aspirin", "Pot să iau o aspirină?"),
        ("algocalmin", "Pot să iau Algocalmin?"),
        ("paracetamol", "Pot să iau Paracetamol?"),
        ("onList", "Pot să iau Nurofen pentru genunchi?"),
    ]

    /// Câte patru transcrieri pe test: fiecare pornește aplicația, iar un test are 3 minute.
    private func voiceCases(_ cases: ArraySlice<(String, String)>) {
        // pacientul demo se reface doar la primul caz, ca Noutățile să adune toate întrebările
        for (index, (label, text)) in cases.enumerated() {
            launch("voice-\(label)", role: .senior, reset: index == 0, now: Self.today(at: "10:00"),
                   env: ["PG_FAKE_TRANSCRIPT": text])
            guard tap("now.checkInButton", timeout: 10) else { continue }
            if tap("checkin.micButton", timeout: 3) {
                if expect("checkin.reply", timeout: 45) == nil { expect("checkin.error", timeout: 1) }
            }
            step("reply", audit: label == "long" || label == "aspirin")
            app.swipeUp()
            step("replyScrolled")
            app.terminate()
        }
    }

    func testVoiceSymptoms() { voiceCases(Self.transcripts[0..<4]) }

    func testVoiceMixed() { voiceCases(Self.transcripts[4..<8]) }

    func testVoiceCanITake() {
        voiceCases(Self.transcripts[8..<12])
        // la aparținător: ce a ajuns în Noutăți din întrebările de mai sus (fără reset)
        launch("voice-feed", role: .caregiver, reset: false)
        tapTab("Noutăți")
        pause(2)
        step("feed", audit: true)
        if let event = first(prefix: "feed.event.") {
            tapElement(event)
            pause(1)
            step("event")
        }
    }

    // MARK: - Noutăți

    func testFeedFloodAndPolling() {
        launch("feedFlood", role: .caregiver)
        // 32 de check-in-uri escaladate (o cădere e semn de alarmă), înainte de prima încărcare a tab-ului
        for i in 0..<32 {
            api("POST", "/v1/patients/pat_demo/checkins", json: ["text": "Am căzut azi \(i) și mă doare șoldul."])
        }
        tapTab("Noutăți")
        pause(3)
        step("flood", audit: true)
        app.swipeUp()
        app.swipeUp()
        step("scrolled")
        // evenimente noi cât lista e derulată: pastila „noutăți ↑”, lista nu se mișcă
        api("POST", "/v1/patients/pat_demo/checkins", json: ["text": "Am scaun negru de ieri."])
        api("POST", "/demo/missed-dose")
        pause(12)
        step("pendingWhileScrolled")
        if tap("feed.newPill", timeout: 2) {
            pause(1)
            step("afterPill")
        }
        // comutare rapidă între tab-uri
        for label in ["Medicamente", "Alerte", "Graf", "Noutăți", "Alerte", "Medicamente", "Noutăți"] {
            app.tabBars.buttons[label].tap()
        }
        pause(1)
        step("afterTabStorm")
    }

    // MARK: - Partajare

    func testShareTwice() {
        launch("shareTwice", role: .caregiver)
        expect("meds.list", timeout: 10)
        for round in 1...2 {
            if tap("meds.shareButton") {
                expect("share.qr", timeout: 10)
                step("qr\(round)")
                tap("share.doneButton")
            }
        }
        burst("meds.shareButton", taps: 3)
        pause(2)
        step("burst")
    }

    // MARK: - Accesibilitate dură

    func testSeniorHugeTextDark() {
        XCUIDevice.shared.appearance = .dark
        launch("hugeDark", role: .senior, now: Self.today(at: "07:05"),
               env: [:], defaults: ["pg.remindersAsked": "NO"])
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        pause(3)
        step("now", audit: true)
        app.swipeUp()
        step("nowScrolled")
        app.swipeUp()
        step("nowBottom")
        tap("now.takenButton", timeout: 3)
        pause(0.8)
        step("taken", audit: true)
        if tap("now.dayButton", timeout: 3) {
            pause(1)
            step("day", audit: true)
            if tap("day.shareButton", timeout: 3) {
                expect("share.qr", timeout: 10)
                step("share", audit: true)
            }
        }
        XCUIDevice.shared.appearance = .light
    }

    // MARK: - Moduri și reset cu detaliul deschis

    func testRoleSwitchAndResetWithDetailOpen() {
        launch("modeSwitch", role: .caregiver, defaults: ["pg.demoMode": "YES"])
        tapTab("Alerte")
        if let card = first(prefix: "alerts.card.") {
            tapElement(card)
            expect("alertDetail")
        }
        // Setările sunt pe ecranele rădăcină: trecem în Medicamente, lăsând detaliul deschis în Alerte
        tapTab("Medicamente")
        if let row = first(prefix: "meds.row.", excludingSuffix: ".alert") { tapElement(row) }
        expect("medDetail")
        step("detailOpen")
        app.navigationBars.buttons.firstMatch.tap()
        if tap("settings.openButton") {
            if let reset = scrollTo("settings.useDemoPatientButton") {
                reset.tap()
                pause(3)
            }
            if let rx = scrollTo("settings.addRxButton") {
                rx.tap()
                pause(3)
            }
            step("settingsAfterReset")
            tap("settings.doneButton")
        }
        tapTab("Alerte")
        pause(1)
        step("alertsDetailAfterReset")
        app.navigationBars.buttons.firstMatch.tap()
        pause(1)
        step("alertsListAfterReset")
        // modul senior din Setări, cu stiva aparținătorului încă plină
        tapTab("Medicamente")
        if tap("settings.openButton") {
            let picker = element("settings.rolePicker")
            if picker.waitForExistence(timeout: 3) {
                picker.buttons.element(boundBy: 0).tap()
            }
            step("rolePicked")
            tap("settings.doneButton")
        }
        pause(2)
        step("afterRoleSwitch", audit: true)
    }
}
