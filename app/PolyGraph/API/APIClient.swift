import Foundation
import OSLog

// MARK: - Corpuri și răspunsuri care nu au schemă proprie în contracts/schema

struct HealthStatus: Codable {
    let ok: Bool
    let mode: String?
}

enum ScanKind: String {
    case box
    case prescription
}

/// O linie de text citită pe telefon (Vision), în ordinea de citire; `height` = înălțimea relativă (0–1).
nonisolated struct OCRLine: Codable, Equatable, Sendable {
    let text: String
    let height: Double
}

/// PATCH /v1/patients/{id}: se trimit doar câmpurile setate.
struct PatientUpdate: Encodable {
    var name: String?
    var birthYear: Int?
    var caregiverName: String?
    var anchors: Anchors?

    enum CodingKeys: String, CodingKey {
        case name
        case birthYear = "birth_year"
        case caregiverName = "caregiver_name"
        case anchors
    }
}

/// PATCH /v1/patients/{id}/meds/{mid}: câmpurile de nivel unu, înlocuite întregi.
struct MedicationUpdate: Encodable {
    var product: Product?
    var substances: [Substance]?
    var dosage: Dosage?
    var prescriber: Prescriber?
    var startDate: String?
    var endDate: String?

    enum CodingKeys: String, CodingKey {
        case product, substances, dosage, prescriber
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

private struct CheckInText: Encodable {
    let text: String
}

// MARK: - Clientul

/// O metodă per rută din `contracts/api/openapi.yaml`. Rutele care întorc HTML (portalul medicului de familie)
/// au doar un constructor de URL, pentru că se deschid în browser / WKWebView.
struct APIClient {
    static let defaultTimeout: TimeInterval = 10
    /// /scan (extracție, eventual LLM) și /checkins (interpretarea textului) durează mai mult
    static let slowTimeout: TimeInterval = 30

    let baseURL: URL?
    let token: String?
    var session: URLSession = .shared

    // MARK: Sistem

    func health() async throws -> HealthStatus {
        try await send(request("GET", "health", authorized: false))
    }

    func mediaURL(_ photoURL: String?) -> URL? {
        guard let photoURL, !photoURL.isEmpty, let baseURL else { return nil }
        return URL(string: photoURL, relativeTo: baseURL)?.absoluteURL
    }

    // MARK: Pacienți

    func createPatient(_ body: PatientCreate) async throws -> PatientCreated {
        try await send(request("POST", "v1/patients", body: body, authorized: false))
    }

    func getPatient(id: String) async throws -> Patient {
        try await send(request("GET", "v1/patients/\(id)"))
    }

    func updatePatient(id: String, _ changes: PatientUpdate) async throws -> Patient {
        try await send(request("PATCH", "v1/patients/\(id)", body: changes))
    }

    // MARK: Medicamente

    func scan(
        patientID: String,
        kind: ScanKind,
        ocrLines: [OCRLine]? = nil,
        image: Data? = nil,
        datamatrix: String? = nil
    ) async throws -> ExtractionResult {
        var form = MultipartForm()
        form.addField("kind", kind.rawValue)
        if let ocrLines, !ocrLines.isEmpty {
            let json = try JSONCoding.encoder.encode(ocrLines)
            form.addField("ocr_lines", String(decoding: json, as: UTF8.self))
        }
        if let datamatrix, !datamatrix.isEmpty {
            form.addField("datamatrix", datamatrix)
        }
        if let image {
            form.addFile("image", filename: "scan.jpg", mimeType: "image/jpeg", data: image)
        }
        var req = try request("POST", "v1/patients/\(patientID)/scan", timeout: Self.slowTimeout)
        req.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = form.encoded()
        return try await send(req)
    }

    func listMeds(patientID: String) async throws -> [MedicationItem] {
        try await send(request("GET", "v1/patients/\(patientID)/meds"))
    }

    func addMed(patientID: String, _ med: MedicationItem) async throws -> MedicationItem {
        try await send(request("POST", "v1/patients/\(patientID)/meds", json: JSONCoding.medicationBody(med)))
    }

    func updateMed(patientID: String, medID: String, _ changes: MedicationUpdate) async throws -> MedicationItem {
        try await send(request("PATCH", "v1/patients/\(patientID)/meds/\(medID)", body: changes))
    }

    func deleteMed(patientID: String, medID: String) async throws {
        _ = try await perform(request("DELETE", "v1/patients/\(patientID)/meds/\(medID)"))
    }

    // MARK: Analiză

    func getAnalysis(patientID: String) async throws -> Analysis {
        try await send(request("GET", "v1/patients/\(patientID)/analysis"))
    }

    func whatIf(patientID: String, _ body: WhatIfRequest) async throws -> WhatIfResult {
        try await send(request("POST", "v1/patients/\(patientID)/what-if", body: body))
    }

    // MARK: Ziua

    /// `date` = `yyyy-MM-dd`; fără el, serverul folosește ziua de azi (ora României).
    func getSchedule(patientID: String, date: String? = nil) async throws -> Schedule {
        let query = date.map { [URLQueryItem(name: "date", value: $0)] } ?? []
        return try await send(request("GET", "v1/patients/\(patientID)/schedule", query: query))
    }

    func recordDose(patientID: String, _ dose: Dose) async throws -> Dose {
        try await send(request("POST", "v1/patients/\(patientID)/doses", body: dose))
    }

    /// Calea normală: transcrierea făcută pe telefon.
    func createCheckIn(patientID: String, text: String) async throws -> CheckIn {
        try await send(request(
            "POST", "v1/patients/\(patientID)/checkins",
            body: CheckInText(text: text), timeout: Self.slowTimeout))
    }

    /// Doar rezerva: audio m4a trimis serverului (Whisper).
    func createCheckIn(patientID: String, audio: Data) async throws -> CheckIn {
        var form = MultipartForm()
        form.addFile("audio", filename: "checkin.m4a", mimeType: "audio/mp4", data: audio)
        var req = try request("POST", "v1/patients/\(patientID)/checkins", timeout: Self.slowTimeout)
        req.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = form.encoded()
        return try await send(req)
    }

    // MARK: Aparținător

    /// Cele mai noi primele; cu `since`, doar evenimentele strict după acel moment.
    func getFeed(patientID: String, since: Date? = nil) async throws -> [FeedEvent] {
        let query = since.map { [URLQueryItem(name: "since", value: JSONCoding.formatISO8601($0))] } ?? []
        return try await send(request("GET", "v1/patients/\(patientID)/feed", query: query))
    }

    // MARK: Partajare

    func createShare(patientID: String) async throws -> ShareLink {
        try await send(request("POST", "v1/patients/\(patientID)/share"))
    }

    func sharePageURL(token: String) -> URL? {
        makeURL("share/\(token)")
    }

    func shareGraphURL(token: String, embed: Bool = true) -> URL? {
        makeURL("share/\(token)/graph", query: [URLQueryItem(name: "embed", value: embed ? "1" : "0")])
    }

    // MARK: Baza de cunoștințe

    func kbSearch(_ query: String) async throws -> KBSearchResult {
        try await send(request("GET", "v1/kb/search", query: [URLQueryItem(name: "q", value: query)]))
    }

    // MARK: Demo

    func demoReset(liveScan: Bool = false) async throws -> PatientCreated {
        let query = liveScan ? [URLQueryItem(name: "live_scan", value: "1")] : []
        return try await send(request("POST", "demo/reset", query: query, authorized: false))
    }

    func demoMissedDose() async throws -> FeedEvent {
        try await send(request("POST", "demo/missed-dose", authorized: false))
    }

    // MARK: - Transport

    private func makeURL(_ path: String, query: [URLQueryItem] = []) -> URL? {
        guard let baseURL else { return nil }
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        return components?.url
    }

    private func request(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        authorized: Bool = true,
        timeout: TimeInterval = APIClient.defaultTimeout
    ) throws -> URLRequest {
        guard let url = makeURL(path, query: query) else { throw APIError.invalidBaseURL }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized {
            guard let token else { throw APIError.missingToken }
            req.setValue(token, forHTTPHeaderField: "X-Patient-Token")
        }
        return req
    }

    private func request<Body: Encodable>(
        _ method: String,
        _ path: String,
        body: Body,
        authorized: Bool = true,
        timeout: TimeInterval = APIClient.defaultTimeout
    ) throws -> URLRequest {
        var req = try request(method, path, authorized: authorized, timeout: timeout)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONCoding.encoder.encode(body)
        return req
    }

    /// Corp JSON deja pregătit (ex. `JSONCoding.medicationBody`, cu `null`-urile cerute de schemă).
    private func request(
        _ method: String,
        _ path: String,
        json: Data,
        authorized: Bool = true,
        timeout: TimeInterval = APIClient.defaultTimeout
    ) throws -> URLRequest {
        var req = try request(method, path, authorized: authorized, timeout: timeout)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = json
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data = try await perform(req)
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            Log.api.error(
                "Decodare eșuată \(req.httpMethod ?? "", privacy: .public) \(req.url?.path() ?? "", privacy: .public): \(String(describing: error), privacy: .public)")
            throw APIError.decoding(String(describing: error))
        }
    }

    private func perform(_ req: URLRequest) async throws -> Data {
        let method = req.httpMethod ?? "GET"
        let path = req.url?.path() ?? ""
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let error as URLError {
            Log.api.error("\(method, privacy: .public) \(path, privacy: .public): \(error.code.rawValue)")
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        Log.api.debug("\(method, privacy: .public) \(path, privacy: .public) → \(http.statusCode)")
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, detail: APIError.detail(from: data))
        }
        return data
    }
}
