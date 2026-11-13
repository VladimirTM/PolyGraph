import SwiftUI

/// Bifa mare de după „Am luat” și punctul momentului din cronologie au același id,
/// așa că `matchedGeometryEffect` o duce pe una în cealaltă.
enum CheckFlight {
    static func id(_ time: String) -> String { "check.\(time)" }
}

/// Rândul de puncte de sus: un punct per moment al zilei, plin cu bifă când e luat.
struct TimelineDots: View {
    let moments: [Moment]
    let current: String?
    /// momentul a cărui bifă încă zboară: punctul lui rămâne gol până aterizează
    let flying: String?
    let namespace: Namespace.ID
    let status: (Moment) -> MomentStatus

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 28

    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(moments) { moment in
                dot(moment)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityIdentifier("now.timeline")
    }

    private func dot(_ moment: Moment) -> some View {
        let state = status(moment)
        let isCurrent = moment.time == current
        return ZStack {
            Circle()
                .strokeBorder(isCurrent ? PgColor.accent : PgColor.textSecondary, lineWidth: isCurrent ? 3 : 2)
            if state == .taken && flying != moment.time {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .foregroundStyle(PgColor.accent)
                    .matchedGeometryEffect(id: CheckFlight.id(moment.time), in: namespace)
            } else if state == .skipped {
                Image(systemName: "minus")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(PgColor.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityIdentifier("now.timeline.\(moment.time)")
    }

    private var summary: String {
        let done = moments.filter { status($0) != .open }.count
        return "Ziua de azi: \(done) din \(moments.count) momente confirmate"
    }
}

/// Cantitatea ca pictogramă: un cerc plin per pastilă întreagă, jumătate de cerc pentru jumătate.
struct QuantityIcon: View {
    let qty: Double

    var body: some View {
        let whole = min(Int(qty.rounded(.down)), 4)
        let half = qty - qty.rounded(.down) >= 0.25
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<whole, id: \.self) { _ in
                Image(systemName: "circle.fill")
            }
            if half {
                Image(systemName: "circle.lefthalf.filled")
            }
        }
        .foregroundStyle(PgColor.accent)
        .accessibilityHidden(true)
    }
}

/// Un medicament din moment: poza cutiei pe toată lățimea, numele, cât și cum. Un singur element VoiceOver.
struct DoseCard: View {
    let dose: DoseElement
    let med: MedicationItem?
    let photoURL: URL?

    @ScaledMetric(relativeTo: .title) private var nameSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(med?.product.brand ?? "Medicament")
                    .font(.system(size: nameSize, weight: .semibold))
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    QuantityIcon(qty: dose.qty)
                    Text(SeniorDay.quantityWords(dose.qty, form: med?.product.form))
                }
                .font(.system(size: textSize, weight: .medium))
                Text(SeniorDay.sentence(dose.instruction))
                    .font(.system(size: textSize))
            }
            .foregroundStyle(PgColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PgColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("now.dose.\(dose.medid)")
    }

    private var photo: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                AsyncImage(url: photoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "pills")
                            .font(.system(size: 56))
                            .foregroundStyle(PgColor.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(PgColor.calmCard)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Cardul liniștit pentru o alertă trimisă și pacientului: fără roșu, fără pictogramă de avertizare.
struct PatientNoticeCard: View {
    let caregiverName: String?
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(message)
                .font(.system(size: textSize, weight: .medium))
                .foregroundStyle(PgColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("now.patientNotice.text")
            SeniorButton("Am înțeles", prominence: .secondary, identifier: "now.patientNotice.okButton", action: onDismiss)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.calmCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("now.patientNotice")
    }

    private var message: String {
        if let name = caregiverName, !name.isEmpty {
            return "Am observat ceva la pastile și am anunțat-o pe \(name). Nu schimbați nimic până vă sună."
        }
        return "Am observat ceva la pastile și am anunțat familia. Nu schimbați nimic până vă sună cineva."
    }
}

/// Permisiunea pentru notificări, cerută o singură dată, cu motivul spus înainte.
struct ReminderAskCard: View {
    let onAllow: () -> Void
    let onLater: () -> Void

    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Vă pot aminti cu un sunet când e ora pastilelor, chiar dacă telefonul e închis.")
                .font(.system(size: textSize, weight: .medium))
                .foregroundStyle(PgColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            SeniorButton("Da, amintiți-mi", systemImage: "bell", prominence: .secondary,
                         identifier: "now.reminders.allowButton", action: onAllow)
            SeniorButton("Nu acum", prominence: .secondary, identifier: "now.reminders.laterButton", action: onLater)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.calmCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("now.reminders")
    }
}

/// Bannerul mare de după „Am luat” / „Am sărit”, cu „Anulează” 5 s.
struct UndoBanner: View {
    let status: DoseStatus
    let onUndo: () -> Void

    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label(status == .taken ? "Am notat că le-ați luat." : "Am notat că le-ați sărit.",
                  systemImage: status == .taken ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: textSize, weight: .semibold))
                .foregroundStyle(PgColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            SeniorButton("Anulează", systemImage: "arrow.uturn.backward", prominence: .secondary,
                         identifier: "now.undoButton", action: onUndo)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.seniorCard, style: .continuous)
                .fill(PgColor.calmCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("now.undoBanner")
    }
}
