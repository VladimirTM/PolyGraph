import SwiftUI

/// Banda discretă de deasupra unei liste care încă arată date vechi (Q3-15): actualizarea n-a mers, dar
/// ce era pe ecran rămâne. „Încearcă din nou” e un buton, nu doar tragerea în jos.
struct StaleBanner: View {
    /// prefixul identificatorilor: „meds” → `meds.staleBanner`, `meds.staleRetryButton`
    let identifier: String
    /// implicit `<identifier>.staleRetryButton`; graful folosește același `graph.retryButton` ca starea de eroare
    var retryIdentifier: String?
    let retry: () async -> Void

    @State private var isRetrying = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nu am putut actualiza.")
                .font(.subheadline)
                .foregroundStyle(PgColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Task {
                    isRetrying = true
                    await retry()
                    isRetrying = false
                }
            } label: {
                if isRetrying {
                    ProgressView()
                } else {
                    Text("Încearcă din nou")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .disabled(isRetrying)
            .accessibilityIdentifier(retryIdentifier ?? "\(identifier).staleRetryButton")
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xxs)
        .background(PgColor.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).staleBanner")
    }
}
