import SwiftUI

/// Alege ecranul de pornire după ce e salvat pe telefon: onboarding, modul senior sau modul aparținător.
struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if !store.didBootstrap {
                ProgressView()
                    .accessibilityIdentifier("root.loading")
            } else if !store.settings.isSignedIn {
                OnboardingView()
            } else if store.settings.role == .senior {
                SeniorRoot()
            } else {
                CaregiverRoot()
            }
        }
        .tint(PgColor.accent)
    }
}
