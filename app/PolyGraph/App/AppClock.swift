import Foundation

/// Ceasul aplicației. Tot ce depinde de „acum” (momentul curent, ziua programului) trece pe aici,
/// ca turul de review să poată fixa dimineața, prânzul sau seara prin `PG_NOW`.
protocol AppClock {
    var now: Date { get }
}

struct SystemClock: AppClock {
    var now: Date { Date() }
}

struct FixedClock: AppClock {
    let now: Date
}
