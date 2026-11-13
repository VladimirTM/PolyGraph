import SwiftUI

/// Spațierile din DESIGN.md 2.4.3: 4 / 8 / 12 / 16 / 24 / 32.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 12
    /// cardurile mari din modul senior
    static let seniorCard: CGFloat = 20
    /// poza cutiei din rândul listei de medicamente
    static let thumbnail: CGFloat = 8
}

enum ControlHeight {
    static let senior: CGFloat = 72
    static let caregiver: CGFloat = 50
}

/// Culorile din Assets.xcassets, fiecare cu variante light / dark / contrast mare.
enum PgColor {
    static let background = Color("PGBackground")
    static let surface = Color("PGSurface")
    static let textPrimary = Color("PGTextPrimary")
    static let textSecondary = Color("PGTextSecondary")
    /// teal liniștit
    static let accent = Color("PGAccent")
    /// textul și iconițele peste accent
    static let onAccent = Color("PGOnAccent")
    /// nisip cald: cardurile pacientului (fără roșu de alarmă)
    static let calmCard = Color("PGCalmCard")
    /// galben deschis sub câmpurile marcate „verificați” la confirmarea scanării (doar aparținător)
    static let review = Color.yellow.opacity(0.22)
}

extension Severity {
    /// Doar pentru aparținător și medicul de familie; pacientul nu vede culori de severitate.
    var color: Color {
        switch self {
        case .critical, .major: .red
        case .moderate: .orange
        case .minor: .gray
        case .info: .blue
        }
    }

    /// Severitatea e mereu însoțită de cuvânt, nu doar de culoare.
    var label: String {
        switch self {
        case .critical: "Critică"
        case .major: "Gravă"
        case .moderate: "Moderată"
        case .minor: "Minoră"
        case .info: "De știut"
        }
    }

    /// pentru sortare: cele grave primele
    var rank: Int {
        switch self {
        case .critical: 0
        case .major: 1
        case .moderate: 2
        case .minor: 3
        case .info: 4
        }
    }
}
