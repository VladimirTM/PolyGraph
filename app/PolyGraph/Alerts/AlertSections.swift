import Foundation

/// Cum se împart alertele pe ecranul Alerte (A3): sus, câte un card pentru fiecare alertă gravă;
/// dedesubt, un card restrâns cu cele moderate și unul cu mâncarea și băutura. Cele `minor` nu apar
/// în aplicație, doar în pagina farmacistului.
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

    /// „12 interacțiuni moderate, de discutat cu farmacistul la următoarea vizită”
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
        return "\(noun.prefix(1).uppercased())\(noun.dropFirst()), de discutat cu farmacistul la următoarea vizită"
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
        case .statusOpen: "Nediscutată încă cu farmacistul"
        case .acknowledged: "Văzută"
        case .verifiedByPharmacist: "Verificată de farmacist"
        }
    }
}
