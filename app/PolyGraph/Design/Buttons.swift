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
