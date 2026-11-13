import OSLog
import SwiftUI

/// Codul QR pentru medicul de familie (A6). Medicul îl scanează cu telefonul; după autentificarea în
/// portal, pacientul îi apare în listă. Linkul expiră după 72 h, iar telefonul cere altul la nevoie.
struct ShareSheet: View {
    enum Audience {
        /// aparținătorul: codul, expirarea, o propoziție despre ce urmează și „Trimite linkul”
        case caregiver
        /// pacientul: doar codul și instrucțiunea, cu text mare și „Gata” ca buton mare
        case senior
    }

    let audience: Audience

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @ScaledMetric(relativeTo: .title2) private var seniorTextSize: CGFloat = 22
    /// fix: codul trebuie să încapă pe ecran și la textul de accesibilitate
    private let qrSide: CGFloat = 260

    private enum Phase {
        case loading
        case ready(expiresAt: Date, url: URL, image: UIImage)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    switch phase {
                    case .loading:
                        ProgressView("Pregătesc codul…")
                            .controlSize(.large)
                            .frame(maxWidth: .infinity, minHeight: qrSide)
                            .accessibilityIdentifier("share.loading")
                    case let .ready(expiresAt, url, image):
                        ready(expiresAt: expiresAt, url: url, image: image)
                    case .failed(let message):
                        failed(message)
                    }
                }
                .padding(Spacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(audience == .senior ? PgColor.background : Color(.systemGroupedBackground))
            .navigationTitle(audience == .senior ? "Codul pentru medic" : "Arată medicului")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if audience == .caregiver {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gata") { dismiss() }
                            .accessibilityIdentifier("share.doneButton")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if audience == .senior {
                    SeniorButton("Gata", identifier: "share.doneButton") { dismiss() }
                        .padding(.horizontal, Spacing.m)
                        .padding(.bottom, Spacing.s)
                        .background(PgColor.background)
                }
            }
        }
        .task { await load() }
    }

    private func ready(expiresAt: Date, url: URL, image: UIImage) -> some View {
        VStack(spacing: Spacing.m) {
            if audience == .senior {
                Text("Arătați acest cod medicului de familie")
                    .font(.system(size: seniorTextSize, weight: .semibold))
                    .foregroundStyle(PgColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("share.instruction")
            }

            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: qrSide, height: qrSide)
                .padding(Spacing.m)
                // alb și în dark mode: camerele citesc codul doar pe fundal deschis
                .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityLabel("Cod QR pentru medicul de familie")
                .accessibilityIdentifier("share.qr")

            // expirarea vine de la server, deci se compară cu ora reală, nu cu PG_NOW
            Text(PgFormat.validUntil(expiresAt, now: Date()))
                .font(audience == .senior ? .system(size: seniorTextSize) : .subheadline)
                .foregroundStyle(audience == .senior ? PgColor.textSecondary : .secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("share.expiry")

            if audience == .caregiver {
                Text("Medicul scanează codul cu telefonul. După ce intră în portal, pacientul îi apare în listă, cu medicamentele și alertele.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                SwiftUI.ShareLink(item: url, subject: Text("Fișa de medicație")) {
                    Label("Trimite linkul", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("share.linkButton")
            }
        }
    }

    @ViewBuilder
    private func failed(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Nu am putut pregăti codul", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            if audience == .caregiver {
                Button("Încearcă din nou") { Task { await load() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("share.retryButton")
            }
        }
        .accessibilityIdentifier("share.error")
        if audience == .senior {
            SeniorButton("Încearcă din nou", prominence: .secondary, identifier: "share.retryButton") {
                Task { await load() }
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            let link = try await store.ensureShareLink()
            // linkul e construit din adresa pe care o folosește telefonul, deci e accesibil din aceeași rețea
            guard let url = store.api.sharePageURL(token: link.shareToken),
                  let image = QRCode.image(for: url.absoluteString)
            else { throw ShareFailure.qrCode }
            withPgAnimation(.pgStandard) {
                phase = .ready(expiresAt: link.expiresAt, url: url, image: image)
            }
        } catch {
            Log.share.error("share: \(String(describing: error), privacy: .public)")
            phase = .failed(
                (error as? LocalizedError)?.errorDescription
                    ?? "Verificați legătura cu serverul și încercați din nou.")
        }
    }

    private enum ShareFailure: LocalizedError {
        case qrCode
        var errorDescription: String? { "Nu am putut desena codul. Încercați din nou." }
    }
}
