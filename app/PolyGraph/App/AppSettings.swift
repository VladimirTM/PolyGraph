import Foundation
import Observation

nonisolated enum AppRole: String, CaseIterable, Identifiable {
    case senior
    case caregiver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .senior: "Pacient"
        case .caregiver: "Aparținător"
        }
    }
}

/// Ce ține minte telefonul între porniri (UserDefaults).
@Observable
final class AppSettings {
    static let defaultBaseURL = "http://127.0.0.1:8000"
    static let demoPatientID = "pat_demo"
    static let demoToken = "demo-token"

    private enum Key {
        static let baseURL = "pg.baseURL"
        static let role = "pg.role"
        static let patientID = "pg.patientID"
        static let patientToken = "pg.patientToken"
        static let demoMode = "pg.demoMode"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Key.baseURL) }
    }

    var role: AppRole {
        didSet { defaults.set(role.rawValue, forKey: Key.role) }
    }

    private(set) var patientID: String? {
        didSet { defaults.set(patientID, forKey: Key.patientID) }
    }

    private(set) var patientToken: String? {
        didSet { defaults.set(patientToken, forKey: Key.patientToken) }
    }

    var demoMode: Bool {
        didSet { defaults.set(demoMode, forKey: Key.demoMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        baseURLString = defaults.string(forKey: Key.baseURL) ?? Self.defaultBaseURL
        role = defaults.string(forKey: Key.role).flatMap(AppRole.init(rawValue:)) ?? .caregiver
        patientID = defaults.string(forKey: Key.patientID)
        patientToken = defaults.string(forKey: Key.patientToken)
        demoMode = defaults.bool(forKey: Key.demoMode)
    }

    var isSignedIn: Bool { patientID != nil && patientToken != nil }

    var baseURL: URL? { Self.normalizedURL(baseURLString) }

    func signIn(patientID: String, token: String) {
        self.patientID = patientID
        patientToken = token
    }

    func signOut() {
        patientID = nil
        patientToken = nil
    }

    /// Acceptă și „192.168.1.10:8000” scris fără schemă, cum îl tastează omul.
    static func normalizedURL(_ text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "http://" + trimmed }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed), url.host() != nil else { return nil }
        return url
    }
}
