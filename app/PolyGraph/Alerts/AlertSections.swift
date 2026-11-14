import Foundation

/// Cum se împart alertele pe ecranul Alerte (A3): sus, câte un card pentru fiecare alertă gravă;
/// dedesubt, un card restrâns cu cele moderate și unul cu mâncarea și băutura. Cele `minor` nu apar
/// în aplicație, doar în portalul medicului de familie.
struct AlertSections {
    /// `critical` și `major`, fără alertele de mâncare, cele mai grave primele
    let serious: [Alert]
    /// `moderate` și `info`, fără alertele de mâncare
    let moderate: [Alert]
    /// toate alertele de mâncare și băutură, indiferent de severitate (fără `minor`)
    let food: [Alert]

    init(_ alerts: [Alert]) {
        let shown = alerts.shownInApp.sortedBySeverity()
        let food = shown.filter { $0.kind == .food }
        let other = shown.filter { $0.kind != .food }
        serious = other.filter { $0.severity == .critical || $0.severity == .major }
        moderate = other.filter { $0.severity == .moderate || $0.severity == .info }
        self.food = food
    }

    var isEmpty: Bool {
        serious.isEmpty && moderate.isEmpty && food.isEmpty
    }

    /// „12 interacțiuni moderate, de discutat cu medicul de familie la următoarea vizită”
    var moderateSummary: String {
        let allInteractions = moderate.allSatisfy { $0.kind == .ddi }
        let noun: String =
            switch (moderate.count, allInteractions) {
            case (1, true): "o interacțiune moderată"
            case (1, false): "o observație moderată"
            case (2...19, true): "\(moderate.count) interacțiuni moderate"
            case (2...19, false): "\(moderate.count) observații moderate"
            case (_, true): "\(moderate.count) de interacțiuni moderate"
            case (_, false): "\(moderate.count) de observații moderate"
            }
        return "\(noun.prefix(1).uppercased())\(noun.dropFirst()), de discutat cu medicul de familie la următoarea vizită"
    }
}

extension Array where Element == Alert {
    /// Ce vede aparținătorul: tot în afară de `minor`.
    var shownInApp: [Alert] {
        filter { $0.severity != .minor }
    }

    /// `critical` → `info`; la aceeași severitate se păstrează ordinea serverului (sortare stabilă).
    func sortedBySeverity() -> [Alert] {
        enumerated()
            .sorted { lhs, rhs in
                lhs.element.severity.rank == rhs.element.severity.rank
                    ? lhs.offset < rhs.offset
                    : lhs.element.severity.rank < rhs.element.severity.rank
            }
            .map(\.element)
    }

    /// Cea mai gravă alertă afișată în aplicație care implică medicamentul.
    func worst(forMed medID: String) -> Alert? {
        shownInApp.filter { $0.medids.contains(medID) }.sortedBySeverity().first
    }
}

extension Alert {
    var isByAnalogy: Bool { basis == .classAnalogy }
}

extension Source {
    /// „DDInter 2.0”: numele sursei, pe înțelesul aparținătorului.
    var displayName: String {
        switch db {
        case .ddinter: "DDInter 2.0"
        case .curated: "DDInter 2.0, verificat de echipă în RCP"
        case .beers: "Criteriile Beers 2023 (American Geriatrics Society)"
        case .stopp: "Criteriile STOPP/START v3"
        case .acb: "Scala ACB (încărcarea anticolinergică)"
        case .rcp: "Rezumatul caracteristicilor produsului (RCP)"
        case .schedule: "Regulile de programare PolyGraph"
        case .app: "PolyGraph"
        }
    }
}

extension AlertStatus {
    var label: String {
        switch self {
        case .statusOpen: "Nediscutată încă cu medicul de familie"
        case .acknowledged: "Văzută"
        case .reviewedByDoctor: "Revizuită de medicul de familie"
        }
    }
}

extension DoctorDecision {
    var label: String {
        switch self {
        case .keep: "Menține tratamentul"
        case .changeAtVisit: "Îl modifică la consultație"
        case .referSpecialist: "Trimite la specialist"
        }
    }
}

/// Alertele noi aduse de un medicament, numărate doar din ce vede aparținătorul, ca rezumatul din portal
/// (Q3-27): grave = cardurile de sus din Alerte (critical + major, fără mâncare); „de discutat” = cele
/// `moderate` fără mâncare. Alertele minore și cele de mâncare nu intră în număr.
struct NewAlerts: Equatable {
    var grave = 0
    var discuss = 0

    init(grave: Int = 0, discuss: Int = 0) {
        self.grave = grave
        self.discuss = discuss
    }

    init(before: [Alert], after: [Alert]) {
        let old = Set(before.map(\.id))
        let sections = AlertSections(after.filter { !old.contains($0.id) })
        grave = sections.serious.count
        discuss = sections.moderate.filter { $0.severity == .moderate }.count
    }

    var isEmpty: Bool { grave == 0 && discuss == 0 }

    static func + (lhs: NewAlerts, rhs: NewAlerts) -> NewAlerts {
        NewAlerts(grave: lhs.grave + rhs.grave, discuss: lhs.discuss + rhs.discuss)
    }

    static func += (lhs: inout NewAlerts, rhs: NewAlerts) {
        lhs = lhs + rhs
    }

    /// „2 alerte grave noi și 2 de discutat”, „o alertă gravă nouă”, „3 alerte noi de discutat”,
    /// „nicio alertă gravă nouă” (cu literă mică; `sentence` o face mare la început de propoziție)
    var text: String {
        let discussText = discuss == 1 ? "una" : Self.number(discuss)
        switch (grave, discuss) {
        case (0, 0): return "nicio alertă gravă nouă"
        case (0, 1): return "o alertă nouă de discutat"
        case (0, _): return "\(Self.number(discuss)) alerte noi de discutat"
        case (_, 0): return Self.graveText(grave)
        default: return "\(Self.graveText(grave)) și \(discussText) de discutat"
        }
    }

    var sentence: String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private static func graveText(_ count: Int) -> String {
        count == 1 ? "o alertă gravă nouă" : "\(number(count)) alerte grave noi"
    }

    /// „3”, „20 de” (aceeași regulă ca `plural` din share/view.py)
    private static func number(_ count: Int) -> String {
        count == 0 || (1...19).contains(count % 100) ? "\(count)" : "\(count) de"
    }
}
