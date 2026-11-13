import Foundation
import SwiftUI
import UIKit

/// Ecranele împinse în stivele modului aparținător. Alerta ține minte dacă vine dintr-un card cu
/// tranziție zoom (tab-ul Alerte) sau din altă parte (graf, detaliul unui medicament).
nonisolated enum CaregiverRoute: Hashable {
    case alert(id: String, zoom: Bool)
    case med(id: String)
}

extension View {
    /// Destinațiile comune; se pun o singură dată, pe rădăcina fiecărei stive.
    func caregiverDestinations(zoom namespace: Namespace.ID? = nil) -> some View {
        navigationDestination(for: CaregiverRoute.self) { route in
            switch route {
            case .alert(let id, let zoom):
                AlertDetailView(alertID: id)
                    .zoomTransition(sourceID: id, in: zoom ? namespace : nil)
            case .med(let id):
                MedDetailView(medID: id)
            }
        }
    }

    /// Detaliul crește din cardul care l-a deschis și se întoarce în el la swipe (skill §7).
    @ViewBuilder
    func zoomTransition(sourceID: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}

/// Punctul de severitate, mereu împreună cu un cuvânt (culoarea singură nu ajunge).
struct SeverityDot: View {
    let severity: Severity
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(severity.color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Numele unui medicament ca etichetă mică (în cardurile de alertă).
struct MedChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }
}
