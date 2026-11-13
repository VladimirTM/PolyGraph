import SwiftUI

@main
struct PolyGraphApp: App {
    @State private var store = AppStore()

    init() {
        // înainte să se termine pornirea, ca o notificare care deschide aplicația să ajungă la delegat
        Reminders.installPresenter()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.bootstrap() }
        }
    }
}
