import XCTest

/// Baza turului de review (etapa Q, docs/PLAN.md „Q0”). Fiecare pas lasă trei atașamente cu numele
/// `<flux>-<NN>-<pas>-<variantă>`: captura (.png), elementele vizibile (.elements.json) și, la finalul
/// unui ecran, auditul de accesibilitate (.audit.json). Testele nu pică pe ecrane lipsă: le notează
/// „absent” în `<flux>-notes-<variantă>.json` și trec mai departe.
@MainActor
class ReviewTestCase: XCTestCase {
    /// Configurația din Review.xctestplan: Light, Dark, AX, Motion, Contrast.
    static var variant: String {
        ProcessInfo.processInfo.environment["PG_REVIEW_VARIANT"] ?? "Light"
    }

    /// Scriptul pune adresa backend-ului pornit de el; implicit, ce folosește și aplicația.
    static var baseURL: String {
        ProcessInfo.processInfo.environment["PG_BASE_URL"] ?? "http://127.0.0.1:8000"
    }

    var app = XCUIApplication()
    private var flow = "flow"
    private var stepIndex = 0
    private var absent: [String] = []
    private var auditIssueCount = 0

    /// Testele care se rulează și în Motion. Capturile se fac după ce animațiile se termină, deci în restul
    /// fluxurilor Motion ar repeta Light; mișcarea însăși se vede în frames/ (video).
    class var motionTests: Set<String> { [] }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let method = name.split(separator: " ").last.map { String($0.dropLast()) } ?? name
        if Self.variant == "Motion" && !Self.motionTests.contains(method) {
            throw XCTSkip("Motion: fără tranziții proprii în acest flux")
        }
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        // run.sh pune aspectul pe simulator înaintea rulării Dark (Q3-I4); asta doar îl confirmă
        XCUIDevice.shared.appearance = Self.variant == "Dark" ? .dark : .light
        // permisiunile de sistem (notificări, cameră) apar peste aplicație în momente greu de prevăzut
        addUIInterruptionMonitor(withDescription: "permisiuni") { alert in
            Self.allow(alert)
        }
    }

    override func tearDown() {
        // un test sărit (Motion) n-a pornit aplicația: n-are ce nota
        guard stepIndex > 0 || !absent.isEmpty else { return super.tearDown() }
        let notes: [String: Any] = [
            "test": name, "variant": Self.variant, "steps": stepIndex,
            "absent": absent, "auditIssues": auditIssueCount,
        ]
        attachJSON(notes, name: "\(flow)-notes-\(Self.variant)")
        app.terminate()
        super.tearDown()
    }

    // MARK: - Pornirea

    enum Role: String { case senior, caregiver }

    /// Pornește aplicația cu variabilele din tabelul Q0. Implicit: pacientul demo recreat pe server.
    func launch(
        _ flow: String, role: Role?, reset: Bool = true, now: String? = nil,
        env extra: [String: String] = [:], defaults: [String: String] = [:]
    ) {
        self.flow = flow
        var env = extra
        env["PG_BASE_URL"] = env["PG_BASE_URL"] ?? Self.baseURL
        if let role {
            env["PG_ROLE"] = role.rawValue
            env["PG_SKIP_ONBOARDING"] = "1"
        }
        if reset { env["PG_RESET_DEMO"] = "1" }
        if let now { env["PG_NOW"] = now }
        if ProcessInfo.processInfo.environment["PG_REDUCE_MOTION"] == "1" { env["PG_REDUCE_MOTION"] = "1" }

        var args = ["-AppleLanguages", "(ro)", "-AppleLocale", "ro_RO"]
        // valorile din domeniul argumentelor au prioritate față de ce a rămas salvat din testul anterior
        let settings = ["pg.speakOnOpen": "NO", "pg.remindersAsked": "YES"].merging(defaults) { $1 }
        for (key, value) in settings.sorted(by: { $0.key < $1.key }) {
            args += ["-\(key)", value]
        }
        // varianta AX: argumentul din test plan ajunge la runner; aplicația îl primește de aici
        let runnerArgs = ProcessInfo.processInfo.arguments
        if let i = runnerArgs.firstIndex(of: "-UIPreferredContentSizeCategoryName"), i + 1 < runnerArgs.count {
            args += [runnerArgs[i], runnerArgs[i + 1]]
        }

        app.launchEnvironment = env
        app.launchArguments = args
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        // după `/demo/reset` și primele cereri; spinner-ul de pornire dispare singur
        let loading = app.descendants(matching: .any)["root.loading"]
        if loading.exists { _ = loading.waitForNonExistence(timeout: 10) }
    }

    /// Ora locală de azi, pentru PG_NOW (programul demo e calculat pentru ziua curentă).
    static func today(at time: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: Date()))T\(time):00"
    }

    // MARK: - Elementele

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Primul element al cărui identificator începe cu `prefix` (ex. `meds.row.`), fără rândurile-copil.
    func first(prefix: String, excludingSuffix suffix: String? = nil) -> XCUIElement? {
        var predicate = "identifier BEGINSWITH %@"
        var arguments: [Any] = [prefix]
        if let suffix {
            predicate += " AND NOT (identifier ENDSWITH %@)"
            arguments.append(suffix)
        }
        let match = app.descendants(matching: .any)
            .matching(NSPredicate(format: predicate, argumentArray: arguments)).firstMatch
        return match.waitForExistence(timeout: 5) ? match : nil
    }

    /// Așteaptă elementul; dacă nu apare, îl notează „absent” și întoarce nil (testul continuă).
    @discardableResult
    func expect(_ identifier: String, timeout: TimeInterval = 5) -> XCUIElement? {
        let target = element(identifier)
        if target.waitForExistence(timeout: timeout) { return target }
        markAbsent(identifier)
        return nil
    }

    /// Atinge elementul dacă există; altfel îl notează „absent”.
    @discardableResult
    func tap(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        guard let target = expect(identifier, timeout: timeout) else { return false }
        tapElement(target, name: identifier)
        return true
    }

    /// Ca `tap`, dar dacă identificatorul lipsește (de ex. suprascris de un container) încearcă eticheta;
    /// identificatorul rămâne notat „absent”, ca review-ul să-l vadă.
    @discardableResult
    func tap(_ identifier: String, orLabel label: String, timeout: TimeInterval = 5) -> Bool {
        if tap(identifier, timeout: timeout) { return true }
        let button = app.buttons[label]
        guard button.waitForExistence(timeout: 1) else { return false }
        tapElement(button)
        return true
    }

    /// Derulează în jos până apare elementul (listele leneșe nu-l au în ierarhie înainte).
    @discardableResult
    func scrollTo(_ identifier: String, swipes: Int = 4) -> XCUIElement? {
        let target = element(identifier)
        for _ in 0..<swipes {
            if target.waitForExistence(timeout: 1), onScreen(target) { return target }
            app.swipeUp()
        }
        if target.exists { return target }
        markAbsent(identifier)
        return nil
    }

    /// Butoanele din tab bar n-au identificator în SwiftUI: se caută după etichetă.
    @discardableResult
    func tapTab(_ label: String) -> Bool {
        let button = app.tabBars.buttons[label]
        let target = button.waitForExistence(timeout: 5) ? button : app.buttons[label]
        guard target.exists else {
            markAbsent("tab \(label)")
            return false
        }
        tapElement(target)
        return true
    }

    /// „Folosește pagina” din camera falsă: identificatorul containerului (`scan.fakeCamera`) îl acoperă pe al
    /// butonului, iar frame-ul raportat e tot ecranul, deci `tap()` ar atinge mijlocul pozei. Butonul stă jos,
    /// centrat (FakeCameraView), așa că îl atingem acolo.
    @discardableResult
    func tapFakeUsePage() -> Bool {
        if tap("scan.fake.usePage", timeout: 2) { return true }
        let button = app.buttons["Folosește pagina"]
        guard button.waitForExistence(timeout: 2) else { return false }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        return true
    }

    func onScreen(_ target: XCUIElement) -> Bool {
        let frame = target.frame
        return !frame.isEmpty && app.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    /// `tap()` derulează singur până la element și ține cont de ce îl acoperă (în AX, butoanele fixate jos),
    /// dar înregistrează un eșec dacă elementul n-are încă frame (tranziție în curs): așteptăm întâi frame-ul.
    func tapElement(_ target: XCUIElement, name: String? = nil) {
        let deadline = Date().addingTimeInterval(3)
        while target.exists && target.frame.isEmpty && Date() < deadline { pause(0.2) }
        // bannerele temporare („Anulează”) pot dispărea între găsire și atingere
        guard target.exists else { return markAbsent(name ?? "element dispărut înainte de atingere") }
        target.tap()
    }

    /// Atinge un element prin coordonate și scrie momentul atingerii în log: scriptul caută linia
    /// `PG_REVIEW_TAP` ca să extragă cadrele din video (0…800 ms după). Doar pentru butoane vizibile deja.
    @discardableResult
    func timedTap(_ identifier: String) -> Bool {
        guard let target = expect(identifier), target.exists else { return false }
        let frame = target.frame
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY))
        print("PG_REVIEW_TAP \(flow) \(Self.variant) \(String(format: "%.3f", Date().timeIntervalSince1970))")
        point.tap()
        return true
    }

    func markAbsent(_ what: String) {
        absent.append(what)
        XCTContext.runActivity(named: "absent: \(what)") { _ in }
    }

    /// Așteaptă fără să ceară un element (animații, rețea).
    func pause(_ seconds: TimeInterval) {
        _ = app.descendants(matching: .any)["pg.review.never"].waitForExistence(timeout: seconds)
    }

    // MARK: - Captura, elementele, auditul

    /// Un pas din tur. `audit: true` la ultimul pas al unui ecran.
    func step(_ name: String, audit: Bool = false) {
        stepIndex += 1
        let base = "\(flow)-\(String(format: "%02d", stepIndex))-\(name)-\(Self.variant)"
        dismissSystemAlert()

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = base
        shot.lifetime = .keepAlways
        add(shot)

        attachJSON(visibleElements(), name: "\(base).elements")
        if audit, let types = Self.auditTypes {
            attachJSON(auditIssues(types), name: "\(base).audit")
        }
    }

    private func visibleElements() -> [[String: Any]] {
        guard let root = try? app.snapshot() else { return [] }
        let screen = root.frame
        var out: [[String: Any]] = []
        func walk(_ node: XCUIElementSnapshot) {
            let frame = node.frame
            let onScreen = !frame.isEmpty && frame.intersects(screen)
            if onScreen && (!node.identifier.isEmpty || !node.label.isEmpty || Self.interactive.contains(node.elementType)) {
                var item: [String: Any] = [
                    "type": Self.typeName(node.elementType),
                    "label": node.label,
                    "identifier": node.identifier,
                    "frame": [frame.minX, frame.minY, frame.width, frame.height].map { Double($0) },
                    // aproximat: activ și în ecran (isHittable real costă o cerere per element)
                    "isHittable": node.isEnabled && screen.contains(CGPoint(x: frame.midX, y: frame.midY)),
                ]
                if let value = node.value.map({ "\($0)" }), !value.isEmpty { item["value"] = value }
                if node.isSelected { item["selected"] = true }
                out.append(item)
            }
            node.children.forEach(walk)
        }
        walk(root)
        return out
    }

    /// Fiecare variantă verifică ce schimbă ea (auditul complet costă câteva secunde pe ecran);
    /// Motion randează la fel ca Light, deci nu se auditează. Cu `PG_REVIEW_AUDIT=0` (`make review AUDIT=0`),
    /// la depanarea unui test, nu se auditează nimic.
    static var auditTypes: XCUIAccessibilityAuditType? {
        if ProcessInfo.processInfo.environment["PG_REVIEW_AUDIT"] == "0" { return nil }
        return switch variant {
        case "Dark", "Contrast": .contrast
        case "AX": [.dynamicType, .textClipped, .hitRegion]
        case "Motion": nil
        default: .all
        }
    }

    private func auditIssues(_ types: XCUIAccessibilityAuditType) -> [[String: Any]] {
        var issues: [[String: Any]] = []
        // un element care nu se mai rezolvă costă ~2 s de reîncercări: oprim căutarea după 1 s per ecran
        let deadline = Date().addingTimeInterval(1)
        do {
            try app.performAccessibilityAudit(for: types) { issue in
                var item: [String: Any] = [
                    "type": Self.auditTypeName(issue.auditType),
                    "description": issue.compactDescription,
                    "detail": issue.detailedDescription,
                ]
                if Date() < deadline, let element = issue.element, element.exists {
                    item["identifier"] = element.identifier
                    item["label"] = element.label
                    let f = element.frame
                    item["frame"] = [f.minX, f.minY, f.width, f.height].map { Double($0) }
                }
                issues.append(item)
                return true  // colectate, nu oprite
            }
        } catch {
            issues.append(["type": "auditError", "description": "\(error)"])
        }
        auditIssueCount += issues.count
        return issues
    }

    func attachJSON(_ object: Any, name: String) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        else { return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Alertele de sistem

    func dismissSystemAlert() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.exists { _ = Self.allow(alert) }
    }

    @discardableResult
    private static func allow(_ alert: XCUIElement) -> Bool {
        let buttons = alert.buttons.allElementsBoundByIndex
        let yes = buttons.first { button in
            let label = button.label.lowercased()
            return !label.hasPrefix("don") && !label.hasPrefix("nu ")
                && ["allow", "permite", "ok"].contains { label.contains($0) }
        }
        guard let target = yes ?? buttons.last else { return false }
        target.tap()
        return true
    }

    // MARK: - Nume lizibile în JSON

    private static let interactive: Set<XCUIElement.ElementType> = [
        .button, .textField, .secureTextField, .switch, .toggle, .slider, .picker, .pickerWheel,
        .segmentedControl, .cell, .link, .tab, .datePicker, .stepper, .textView, .menuItem,
    ]

    private static let typeNames: [XCUIElement.ElementType: String] = [
        .application: "application", .window: "window", .other: "other", .group: "group",
        .button: "button", .staticText: "staticText", .textField: "textField", .secureTextField: "secureTextField",
        .switch: "switch", .toggle: "toggle", .slider: "slider", .picker: "picker", .pickerWheel: "pickerWheel",
        .segmentedControl: "segmentedControl", .cell: "cell", .table: "table", .collectionView: "collectionView",
        .scrollView: "scrollView", .image: "image", .icon: "icon", .link: "link", .tabBar: "tabBar", .tab: "tab",
        .navigationBar: "navigationBar", .toolbar: "toolbar", .alert: "alert", .sheet: "sheet",
        .webView: "webView", .progressIndicator: "progressIndicator", .activityIndicator: "activityIndicator",
        .datePicker: "datePicker", .stepper: "stepper", .textView: "textView", .map: "map",
        .keyboard: "keyboard", .key: "key", .menu: "menu", .menuItem: "menuItem", .statusBar: "statusBar",
    ]

    static func typeName(_ type: XCUIElement.ElementType) -> String {
        typeNames[type] ?? "type\(type.rawValue)"
    }

    static func auditTypeName(_ type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"), (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"), (.trait, "trait"),
        ]
        let matched = names.filter { type.contains($0.0) }.map(\.1)
        return matched.isEmpty ? "raw\(type.rawValue)" : matched.joined(separator: ",")
    }
}
