import SwiftUI
import UIKit

// Tokenii de mișcare (DESIGN.md 2.4.3). Implicit fără overshoot; bounce doar după un gest cu impuls.
extension Animation {
    /// apariții, layout, feed
    static let pgStandard = Animation.spring(response: 0.35, dampingFraction: 1.0)
    /// revenirea după apăsare
    static let pgQuick = Animation.spring(response: 0.25, dampingFraction: 1.0)
    /// bifa care zboară
    static let pgMove = Animation.spring(response: 0.40, dampingFraction: 1.0)
    /// doar după un gest cu impuls
    static let pgFlick = Animation.spring(response: 0.30, dampingFraction: 0.8)
    /// rezerva pentru Reduce Motion: fără spring, fără mișcare spațială
    static let pgReduced = Animation.easeInOut(duration: 0.2)
}

enum PgMotion {
    /// Reduce Motion din sistem sau, în Debug, `PG_REDUCE_MOTION=1` (simulatorul nu-l poate porni din linia de comandă).
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled || DebugEnvironment.current.reduceMotion
    }

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .pgReduced : animation
    }

    /// Tranzițiile spațiale devin `.opacity` cu Reduce Motion.
    static func transition(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }
}

/// `withAnimation` cu tokenii PolyGraph; cu Reduce Motion, orice spring devine `.easeInOut(0.2)`.
@discardableResult
func withPgAnimation<R>(
    _ animation: Animation = .pgStandard,
    reduceMotion: Bool = PgMotion.isReduceMotionEnabled,
    _ body: () throws -> R
) rethrows -> R {
    try withAnimation(PgMotion.resolve(animation, reduceMotion: reduceMotion), body)
}

extension EnvironmentValues {
    /// Reduce Motion pentru view-uri: setarea de sistem sau `PG_REDUCE_MOTION`.
    nonisolated var pgReduceMotion: Bool {
        accessibilityReduceMotion || DebugEnvironment.current.reduceMotion
    }
}

private struct PgAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.pgReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(PgMotion.resolve(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// `.animation(_:value:)` care respectă Reduce Motion.
    func pgAnimation<Value: Equatable>(_ animation: Animation = .pgStandard, value: Value) -> some View {
        modifier(PgAnimationModifier(animation: animation, value: value))
    }
}
