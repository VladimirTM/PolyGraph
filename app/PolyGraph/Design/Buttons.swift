import Foundation
import SwiftUI

/// Răspuns instant la atingere (skill §1): butonul se micșorează din momentul în care degetul îl atinge
/// și revine cu `pgQuick` la ridicare. Cu Reduce Motion rămâne doar estomparea.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableLabel(configuration: configuration)
    }
}

private struct PressableLabel: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.pgReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            // la apăsare fără animație (instant), la eliberare cu spring
            .animation(
                configuration.isPressed ? nil : PgMotion.resolve(.pgQuick, reduceMotion: reduceMotion),
                value: configuration.isPressed)
    }
}

/// Ignoră al doilea apel venit în `interval` după primul (tremor, dublă atingere). Backend-ul e
/// oricum idempotent pe doză; asta oprește și dublarea efectelor locale (haptic, voce, animație).
final class GuardedAction {
    static let seniorInterval: TimeInterval = 1.0

    let interval: TimeInterval
    private let uptime: () -> TimeInterval
    private var lastRun: TimeInterval?

    /// `uptime` e ceasul monoton al sistemului; testele îl înlocuiesc.
    init(interval: TimeInterval, uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.interval = interval
        self.uptime = uptime
    }

    /// Ignoră atingerile din următorul `interval`, ca și cum acțiunea tocmai ar fi rulat:
    /// pentru un buton care apare sub degetul care încă apasă (Q3-03).
    func arm() {
        lastRun = uptime()
    }

    /// Rulează `action` dacă nu a mai rulat în ultimul `interval`; întoarce dacă a rulat.
    @discardableResult
    func callAsFunction(_ action: () -> Void) -> Bool {
        let now = uptime()
        if let lastRun, now - lastRun < interval { return false }
        lastRun = now
        action()
        return true
    }
}

/// Butonul modului senior: 72 pt, pe toată lățimea, text de 22 pt care crește cu Dynamic Type,
/// cu răspuns instant și a doua atingere din aceeași secundă ignorată.
struct SeniorButton: View {
    enum Prominence {
        case primary
        case secondary
    }

    private let title: String
    private let systemImage: String?
    private let prominence: Prominence
    private let identifier: String
    private let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var fontSize: CGFloat = 22
    @Environment(\.isEnabled) private var isEnabled
    @State private var guarded = GuardedAction(interval: GuardedAction.seniorInterval)

    init(
        _ title: String,
        systemImage: String? = nil,
        prominence: Prominence = .primary,
        identifier: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominence = prominence
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button {
            guarded(action)
        } label: {
            HStack(spacing: Spacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .multilineTextAlignment(.center)
            }
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(prominence == .primary ? PgColor.onAccent : PgColor.accent)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: ControlHeight.senior)
            .background(
                RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                    .fill(prominence == .primary ? PgColor.accent : PgColor.surface))
            .overlay {
                if prominence == .secondary {
                    RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                        .strokeBorder(PgColor.accent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// `.borderedProminent` cu eticheta în `PgColor.onAccent`. Stilul de sistem scrie cu alb, iar pe teal-ul
/// deschis din Dark (și pe ecranul de scanare, mereu întunecat) contrastul e ~2:1 (Q3-16, auditul pe
/// `scan.retryButton`); `onAccent` are variantele lui pentru light / dark / contrast mare.
struct PgProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .foregroundStyle(PgColor.onAccent)
        }
        .buttonStyle(.pgProminent)
    }
}

extension PrimitiveButtonStyle where Self == PgProminentButtonStyle {
    static var pgProminent: PgProminentButtonStyle { PgProminentButtonStyle() }
}

/// Eticheta lui „Gata” din bară (`.confirmationAction`). Pe iOS 26 sistemul îl desenează plin, în accent, cu
/// text alb (același contrast slab ca mai sus, în Dark), deci eticheta ia `onAccent`; pe iOS 18 e text
/// în accent pe bară și rămâne așa.
struct BarConfirmLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        if #available(iOS 26, *) {
            Text(title).foregroundStyle(PgColor.onAccent)
        } else {
            Text(title)
        }
    }
}
