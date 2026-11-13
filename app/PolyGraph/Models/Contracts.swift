// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let alert = try Alert(json)
//   let analysis = try Analysis(json)
//   let checkIn = try CheckIn(json)
//   let dose = try Dose(json)
//   let extractionResult = try ExtractionResult(json)
//   let feedEvent = try FeedEvent(json)
//   let graph = try Graph(json)
//   let kBSearchResult = try KBSearchResult(json)
//   let medicationItem = try MedicationItem(json)
//   let patient = try Patient(json)
//   let patientCreate = try PatientCreate(json)
//   let patientCreated = try PatientCreated(json)
//   let schedule = try Schedule(json)
//   let shareLink = try ShareLink(json)
//   let whatIfRequest = try WhatIfRequest(json)
//   let whatIfResult = try WhatIfResult(json)

import Foundation

/// Răspunsul la GET /analysis.
// MARK: - Analysis
struct Analysis: Codable {
    let acbTotal: Int
    let alerts: [Alert]
    let analyzedAt: Date
    let graph: Graph

    enum CodingKeys: String, CodingKey {
        case acbTotal = "acb_total"
        case alerts
        case analyzedAt = "analyzed_at"
        case graph
    }
}

// MARK: Analysis convenience initializers and mutators

extension Analysis {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Analysis.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        acbTotal: Int? = nil,
        alerts: [Alert]? = nil,
        analyzedAt: Date? = nil,
        graph: Graph? = nil
    ) -> Analysis {
        return Analysis(
            acbTotal: acbTotal ?? self.acbTotal,
            alerts: alerts ?? self.alerts,
            analyzedAt: analyzedAt ?? self.analyzedAt,
            graph: graph ?? self.graph
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// O problemă găsită determinist în regimul pacientului. Plan, secțiunea 5.3.
// MARK: - Alert
struct Alert: Codable {
    /// contact_doctor = înainte de următoarea doză; ask_doctor = la următoarea vizită la medicul
    /// de familie
    let action: Action
    let analogy: Analogy?
    let basis: Basis
    let detail: String
    /// determinist: al_<kind>_<id-uri sortate>[_<regulă / aliment>]
    let id: String
    let kind: Kind
    let medids: [String]
    /// textul pentru pacient: fără termeni tehnici, fără roșu
    let patientText: String
    /// nu conține niciodată „opriți”, „nu mai luați” sau doze
    let recommendation: String
    let resolution: Resolution?
    /// doctor = medicul de familie (portalul)
    let routeTo: [RouteTo]
    let severity: Severity
    let source: Source
    let status: AlertStatus
    let title: String

    enum CodingKeys: String, CodingKey {
        case action, analogy, basis, detail, id, kind
        case medids = "med_ids"
        case patientText = "patient_text"
        case recommendation, resolution
        case routeTo = "route_to"
        case severity, source, status, title
    }
}

// MARK: Alert convenience initializers and mutators

extension Alert {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Alert.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        action: Action? = nil,
        analogy: Analogy?? = nil,
        basis: Basis? = nil,
        detail: String? = nil,
        id: String? = nil,
        kind: Kind? = nil,
        medids: [String]? = nil,
        patientText: String? = nil,
        recommendation: String? = nil,
        resolution: Resolution?? = nil,
        routeTo: [RouteTo]? = nil,
        severity: Severity? = nil,
        source: Source? = nil,
        status: AlertStatus? = nil,
        title: String? = nil
    ) -> Alert {
        return Alert(
            action: action ?? self.action,
            analogy: analogy ?? self.analogy,
            basis: basis ?? self.basis,
            detail: detail ?? self.detail,
            id: id ?? self.id,
            kind: kind ?? self.kind,
            medids: medids ?? self.medids,
            patientText: patientText ?? self.patientText,
            recommendation: recommendation ?? self.recommendation,
            resolution: resolution ?? self.resolution,
            routeTo: routeTo ?? self.routeTo,
            severity: severity ?? self.severity,
            source: source ?? self.source,
            status: status ?? self.status,
            title: title ?? self.title
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// contact_doctor = înainte de următoarea doză; ask_doctor = la următoarea vizită la medicul
/// de familie
enum Action: String, Codable {
    case askDoctor = "ask_doctor"
    case avoidFood = "avoid_food"
    case contactDoctor = "contact_doctor"
    case monitor = "monitor"
    case replaceBox = "replace_box"
    case separateTimes = "separate_times"
}

// MARK: - Analogy
struct Analogy: Codable {
    let atc4: String
    /// substanța din aceeași clasă prin care s-a evaluat (ex. warfarină)
    let via: String
}

// MARK: Analogy convenience initializers and mutators

extension Analogy {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Analogy.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        atc4: String? = nil,
        via: String? = nil
    ) -> Analogy {
        return Analogy(
            atc4: atc4 ?? self.atc4,
            via: via ?? self.via
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum Basis: String, Codable {
    case classAnalogy = "class_analogy"
    case curated = "curated"
    case direct = "direct"
}

enum Kind: String, Codable {
    case anticholinergic = "anticholinergic"
    case ddi = "ddi"
    case duplicate = "duplicate"
    case elderlypim = "elderly_pim"
    case expired = "expired"
    case food = "food"
    case symptom = "symptom"
    case timing = "timing"
}

// MARK: - Resolution
struct Resolution: Codable {
    let at: Date
    let by: By
    /// decizia medicului de familie: menține / modifică la consultație / trimite la specialist;
    /// null pentru aparținător
    let decision: DoctorDecision?
    let note: String
}

// MARK: Resolution convenience initializers and mutators

extension Resolution {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Resolution.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        at: Date? = nil,
        by: By? = nil,
        decision: DoctorDecision?? = nil,
        note: String? = nil
    ) -> Resolution {
        return Resolution(
            at: at ?? self.at,
            by: by ?? self.by,
            decision: decision ?? self.decision,
            note: note ?? self.note
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum By: String, Codable {
    case caregiver = "caregiver"
    case doctor = "doctor"
}

enum DoctorDecision: String, Codable {
    case changeAtVisit = "change_at_visit"
    case keep = "keep"
    case referSpecialist = "refer_specialist"
}

enum RouteTo: String, Codable {
    case caregiver = "caregiver"
    case doctor = "doctor"
    case patient = "patient"
}

/// cea mai gravă alertă a nodului, dacă există
enum Severity: String, Codable {
    case critical = "critical"
    case info = "info"
    case major = "major"
    case minor = "minor"
    case moderate = "moderate"
}

// MARK: - Source
struct Source: Codable {
    let db: DB
    let ref, url: String?
}

// MARK: Source convenience initializers and mutators

extension Source {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Source.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        db: DB? = nil,
        ref: String?? = nil,
        url: String?? = nil
    ) -> Source {
        return Source(
            db: db ?? self.db,
            ref: ref ?? self.ref,
            url: url ?? self.url
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum DB: String, Codable {
    case acb = "acb"
    case app = "app"
    case beers = "beers"
    case curated = "curated"
    case ddinter = "ddinter"
    case rcp = "rcp"
    case schedule = "schedule"
    case stopp = "stopp"
}

enum AlertStatus: String, Codable {
    case acknowledged = "acknowledged"
    case reviewedByDoctor = "reviewed_by_doctor"
    case statusOpen = "open"
}

/// Graful terapeutic al pacientului, în formatul Cytoscape (elements). Plan, secțiunea 5.6.
// MARK: - Graph
struct Graph: Codable {
    let edges: [GraphEdge]
    let nodes: [GraphNode]
}

// MARK: Graph convenience initializers and mutators

extension Graph {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Graph.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        edges: [GraphEdge]? = nil,
        nodes: [GraphNode]? = nil
    ) -> Graph {
        return Graph(
            edges: edges ?? self.edges,
            nodes: nodes ?? self.nodes
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - GraphEdge
struct GraphEdge: Codable {
    let data: GraphEdgeData
}

// MARK: GraphEdge convenience initializers and mutators

extension GraphEdge {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(GraphEdge.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: GraphEdgeData? = nil
    ) -> GraphEdge {
        return GraphEdge(
            data: data ?? self.data
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - GraphEdgeData
struct GraphEdgeData: Codable {
    let alertid: String?
    let id: String?
    /// unknown = pereche DDInter fără nivel: muchie gri, fără alertă
    let severity: GraphEdgeSeverity?
    let source, target: String
    let type: GraphEdgeType

    enum CodingKeys: String, CodingKey {
        case alertid = "alert_id"
        case id, severity, source, target, type
    }
}

// MARK: GraphEdgeData convenience initializers and mutators

extension GraphEdgeData {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(GraphEdgeData.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        alertid: String?? = nil,
        id: String?? = nil,
        severity: GraphEdgeSeverity?? = nil,
        source: String? = nil,
        target: String? = nil,
        type: GraphEdgeType? = nil
    ) -> GraphEdgeData {
        return GraphEdgeData(
            alertid: alertid ?? self.alertid,
            id: id ?? self.id,
            severity: severity ?? self.severity,
            source: source ?? self.source,
            target: target ?? self.target,
            type: type ?? self.type
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// unknown = pereche DDInter fără nivel: muchie gri, fără alertă
enum GraphEdgeSeverity: String, Codable {
    case critical = "critical"
    case major = "major"
    case minor = "minor"
    case moderate = "moderate"
    case unknown = "unknown"
}

enum GraphEdgeType: String, Codable {
    case contains = "contains"
    case foodInteraction = "food_interaction"
    case inClass = "in_class"
    case interacts = "interacts"
    case possiblyRelated = "possibly_related"
    case reported = "reported"
    case takes = "takes"
}

// MARK: - GraphNode
struct GraphNode: Codable {
    let data: GraphNodeData
}

// MARK: GraphNode convenience initializers and mutators

extension GraphNode {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(GraphNode.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: GraphNodeData? = nil
    ) -> GraphNode {
        return GraphNode(
            data: data ?? self.data
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - GraphNodeData
struct GraphNodeData: Codable {
    /// p | med_NN | s:<ATC5> | c:<ATC4> | f:<aliment> | y:<cod simptom>
    let id: String
    let label: String
    let prescriber: String?
    /// cea mai gravă alertă a nodului, dacă există
    let severity: Severity?
    let type: GraphNodeType
}

// MARK: GraphNodeData convenience initializers and mutators

extension GraphNodeData {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(GraphNodeData.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        id: String? = nil,
        label: String? = nil,
        prescriber: String?? = nil,
        severity: Severity?? = nil,
        type: GraphNodeType? = nil
    ) -> GraphNodeData {
        return GraphNodeData(
            id: id ?? self.id,
            label: label ?? self.label,
            prescriber: prescriber ?? self.prescriber,
            severity: severity ?? self.severity,
            type: type ?? self.type
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum GraphNodeType: String, Codable {
    case atcClass = "atc_class"
    case food = "food"
    case patient = "patient"
    case product = "product"
    case substance = "substance"
    case symptom = "symptom"
}

/// Un check-in vocal transcris pe telefon și interpretat determinist. Plan, secțiunea 5.5.
// MARK: - CheckIn
struct CheckIn: Codable {
    let at: Date
    let correlations: [Correlation]
    let escalate: Bool
    let id: String
    let intent: Intent
    /// din template, nu text liber de LLM
    let replyText: String
    let symptoms: [Symptom]
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case at, correlations, escalate, id, intent
        case replyText = "reply_text"
        case symptoms, transcript
    }
}

// MARK: CheckIn convenience initializers and mutators

extension CheckIn {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CheckIn.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        at: Date? = nil,
        correlations: [Correlation]? = nil,
        escalate: Bool? = nil,
        id: String? = nil,
        intent: Intent? = nil,
        replyText: String? = nil,
        symptoms: [Symptom]? = nil,
        transcript: String? = nil
    ) -> CheckIn {
        return CheckIn(
            at: at ?? self.at,
            correlations: correlations ?? self.correlations,
            escalate: escalate ?? self.escalate,
            id: id ?? self.id,
            intent: intent ?? self.intent,
            replyText: replyText ?? self.replyText,
            symptoms: symptoms ?? self.symptoms,
            transcript: transcript ?? self.transcript
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Correlation
struct Correlation: Codable {
    let basis: String
    let medids: [String]
    let symptom: String

    enum CodingKeys: String, CodingKey {
        case basis
        case medids = "med_ids"
        case symptom
    }
}

// MARK: Correlation convenience initializers and mutators

extension Correlation {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Correlation.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        basis: String? = nil,
        medids: [String]? = nil,
        symptom: String? = nil
    ) -> Correlation {
        return Correlation(
            basis: basis ?? self.basis,
            medids: medids ?? self.medids,
            symptom: symptom ?? self.symptom
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum Intent: String, Codable {
    case canITake = "can_i_take"
    case other = "other"
    case symptomReport = "symptom_report"
    case whichPillNow = "which_pill_now"
}

// MARK: - Symptom
struct Symptom: Codable {
    /// doar coduri din contracts/symptoms.md (verificat de validate.py)
    let code: String
    let label: String
    let severity: SymptomSeverity
}

// MARK: Symptom convenience initializers and mutators

extension Symptom {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Symptom.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        code: String? = nil,
        label: String? = nil,
        severity: SymptomSeverity? = nil
    ) -> Symptom {
        return Symptom(
            code: code ?? self.code,
            label: label ?? self.label,
            severity: severity ?? self.severity
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum SymptomSeverity: String, Codable {
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
}

/// O doză confirmată / sărită / anulată. Idempotent pe med_id + scheduled_at.
// MARK: - Dose
struct Dose: Codable {
    let medid: String
    /// completat de server
    let recordedAt: Date?
    let scheduledAt: Date
    /// pending = anularea din banner-ul „Anulează”
    let status: DoseStatus

    enum CodingKeys: String, CodingKey {
        case medid = "med_id"
        case recordedAt = "recorded_at"
        case scheduledAt = "scheduled_at"
        case status
    }
}

// MARK: Dose convenience initializers and mutators

extension Dose {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Dose.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        medid: String? = nil,
        recordedAt: Date?? = nil,
        scheduledAt: Date? = nil,
        status: DoseStatus? = nil
    ) -> Dose {
        return Dose(
            medid: medid ?? self.medid,
            recordedAt: recordedAt ?? self.recordedAt,
            scheduledAt: scheduledAt ?? self.scheduledAt,
            status: status ?? self.status
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// pending = anularea din banner-ul „Anulează”
enum DoseStatus: String, Codable {
    case pending = "pending"
    case skipped = "skipped"
    case taken = "taken"
}

/// Răspunsul la POST /scan: candidați de confirmat, nesalvați. Plan, secțiunile 5.7 și B3.
// MARK: - ExtractionResult
struct ExtractionResult: Codable {
    let candidates: [MedicationItem]
    /// textul OCR primit, unit pe linii (pentru depanare)
    let rawText: String?
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case candidates
        case rawText = "raw_text"
        case warnings
    }
}

// MARK: ExtractionResult convenience initializers and mutators

extension ExtractionResult {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ExtractionResult.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        candidates: [MedicationItem]? = nil,
        rawText: String?? = nil,
        warnings: [String]? = nil
    ) -> ExtractionResult {
        return ExtractionResult(
            candidates: candidates ?? self.candidates,
            rawText: rawText ?? self.rawText,
            warnings: warnings ?? self.warnings
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Un medicament din lista pacientului (o cutie / o linie de rețetă). Plan, secțiunea 5.2.
// MARK: - MedicationItem
struct MedicationItem: Codable {
    let dosage: Dosage
    /// setat pentru cure scurte; după end_date medicamentul iese din analiză
    let endDate: String?
    let id: String
    let match: Match
    let photourl: String?
    let prescriber: Prescriber
    let product: Product
    let source: MedicationSource
    let startDate: String?
    let substances: [Substance]

    enum CodingKeys: String, CodingKey {
        case dosage
        case endDate = "end_date"
        case id, match
        case photourl = "photo_url"
        case prescriber, product, source
        case startDate = "start_date"
        case substances
    }
}

// MARK: MedicationItem convenience initializers and mutators

extension MedicationItem {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(MedicationItem.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        dosage: Dosage? = nil,
        endDate: String?? = nil,
        id: String? = nil,
        match: Match? = nil,
        photourl: String?? = nil,
        prescriber: Prescriber? = nil,
        product: Product? = nil,
        source: MedicationSource? = nil,
        startDate: String?? = nil,
        substances: [Substance]? = nil
    ) -> MedicationItem {
        return MedicationItem(
            dosage: dosage ?? self.dosage,
            endDate: endDate ?? self.endDate,
            id: id ?? self.id,
            match: match ?? self.match,
            photourl: photourl ?? self.photourl,
            prescriber: prescriber ?? self.prescriber,
            product: product ?? self.product,
            source: source ?? self.source,
            startDate: startDate ?? self.startDate,
            substances: substances ?? self.substances
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Dosage
struct Dosage: Codable {
    let asNeeded: Bool
    /// notația „dimineața-prânz-seara(-culcare)”; fracțiile sunt permise
    let pattern: Pattern
    /// textul de pe rețetă / cutie (ex. „1/2 cp seara”)
    let raw: String?
    let withFood: WithFood

    enum CodingKeys: String, CodingKey {
        case asNeeded = "as_needed"
        case pattern, raw
        case withFood = "with_food"
    }
}

// MARK: Dosage convenience initializers and mutators

extension Dosage {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Dosage.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        asNeeded: Bool? = nil,
        pattern: Pattern? = nil,
        raw: String?? = nil,
        withFood: WithFood? = nil
    ) -> Dosage {
        return Dosage(
            asNeeded: asNeeded ?? self.asNeeded,
            pattern: pattern ?? self.pattern,
            raw: raw ?? self.raw,
            withFood: withFood ?? self.withFood
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// notația „dimineața-prânz-seara(-culcare)”; fracțiile sunt permise
// MARK: - Pattern
struct Pattern: Codable {
    let bedtime, evening, morning, noon: Double
}

// MARK: Pattern convenience initializers and mutators

extension Pattern {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Pattern.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bedtime: Double? = nil,
        evening: Double? = nil,
        morning: Double? = nil,
        noon: Double? = nil
    ) -> Pattern {
        return Pattern(
            bedtime: bedtime ?? self.bedtime,
            evening: evening ?? self.evening,
            morning: morning ?? self.morning,
            noon: noon ?? self.noon
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum WithFood: String, Codable {
    case afterMeal = "after_meal"
    case any = "any"
    case beforeMeal = "before_meal"
    case emptyStomach = "empty_stomach"
    case withMeal = "with_meal"
}

// MARK: - Match
struct Match: Codable {
    let confidence: Double
    let method: Method
    /// true dacă confidence < 0.85 sau o substanță nu are atc
    let needsReview: Bool

    enum CodingKeys: String, CodingKey {
        case confidence, method
        case needsReview = "needs_review"
    }
}

// MARK: Match convenience initializers and mutators

extension Match {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Match.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        confidence: Double? = nil,
        method: Method? = nil,
        needsReview: Bool? = nil
    ) -> Match {
        return Match(
            confidence: confidence ?? self.confidence,
            method: method ?? self.method,
            needsReview: needsReview ?? self.needsReview
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum Method: String, Codable {
    case exactBrand = "exact_brand"
    case exactDci = "exact_dci"
    case fuzzy = "fuzzy"
    case gtinCache = "gtin_cache"
    case manual = "manual"
    case methodOverride = "override"
}

// MARK: - Prescriber
struct Prescriber: Codable {
    let name: String?
    /// null = fără rețetă (OTC)
    let specialty: String?
}

// MARK: Prescriber convenience initializers and mutators

extension Prescriber {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Prescriber.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        name: String?? = nil,
        specialty: String?? = nil
    ) -> Prescriber {
        return Prescriber(
            name: name ?? self.name,
            specialty: specialty ?? self.specialty
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Product
struct Product: Codable {
    let batch: String?
    let brand: String
    let expiry, form: String?
    let gtin: String?
    let packSize: Int?
    let strengthText: String?

    enum CodingKeys: String, CodingKey {
        case batch, brand, expiry, form, gtin
        case packSize = "pack_size"
        case strengthText = "strength_text"
    }
}

// MARK: Product convenience initializers and mutators

extension Product {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Product.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        batch: String?? = nil,
        brand: String? = nil,
        expiry: String?? = nil,
        form: String?? = nil,
        gtin: String?? = nil,
        packSize: Int?? = nil,
        strengthText: String?? = nil
    ) -> Product {
        return Product(
            batch: batch ?? self.batch,
            brand: brand ?? self.brand,
            expiry: expiry ?? self.expiry,
            form: form ?? self.form,
            gtin: gtin ?? self.gtin,
            packSize: packSize ?? self.packSize,
            strengthText: strengthText ?? self.strengthText
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum MedicationSource: String, Codable {
    case datamatrix = "datamatrix"
    case manual = "manual"
    case photoBox = "photo_box"
    case photoRx = "photo_rx"
    case voice = "voice"
}

// MARK: - Substance
struct Substance: Codable {
    let atc: String?
    /// DCI în latină, ca în catalogul românesc (ex. ACENOCUMAROLUM)
    let dci: String?
    /// INN în engleză, ca în DDInter (ex. acenocoumarol)
    let inn: String?
    let strengthMg: Double?

    enum CodingKeys: String, CodingKey {
        case atc, dci, inn
        case strengthMg = "strength_mg"
    }
}

// MARK: Substance convenience initializers and mutators

extension Substance {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Substance.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        atc: String?? = nil,
        dci: String?? = nil,
        inn: String?? = nil,
        strengthMg: Double?? = nil
    ) -> Substance {
        return Substance(
            atc: atc ?? self.atc,
            dci: dci ?? self.dci,
            inn: inn ?? self.inn,
            strengthMg: strengthMg ?? self.strengthMg
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Un eveniment din tab-ul Noutăți al aparținătorului (GET /feed).
// MARK: - FeedEvent
struct FeedEvent: Codable {
    let alertid: String?
    let at: Date
    let body: String
    let checkinid: String?
    let id: String
    let medids: [String]
    let severity: Severity?
    let title: String
    let type: FeedEventType

    enum CodingKeys: String, CodingKey {
        case alertid = "alert_id"
        case at, body
        case checkinid = "checkin_id"
        case id
        case medids = "med_ids"
        case severity, title, type
    }
}

// MARK: FeedEvent convenience initializers and mutators

extension FeedEvent {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FeedEvent.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        alertid: String?? = nil,
        at: Date? = nil,
        body: String? = nil,
        checkinid: String?? = nil,
        id: String? = nil,
        medids: [String]? = nil,
        severity: Severity?? = nil,
        title: String? = nil,
        type: FeedEventType? = nil
    ) -> FeedEvent {
        return FeedEvent(
            alertid: alertid ?? self.alertid,
            at: at ?? self.at,
            body: body ?? self.body,
            checkinid: checkinid ?? self.checkinid,
            id: id ?? self.id,
            medids: medids ?? self.medids,
            severity: severity ?? self.severity,
            title: title ?? self.title,
            type: type ?? self.type
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

enum FeedEventType: String, Codable {
    case alertNew = "alert_new"
    case checkin = "checkin"
    case doctorReviewed = "doctor_reviewed"
    case doseMissed = "dose_missed"
}

/// Răspunsul la GET /v1/kb/search (autocomplete la adăugarea manuală).
// MARK: - KBSearchResult
struct KBSearchResult: Codable {
    let results: [KBSearchHit]
}

// MARK: KBSearchResult convenience initializers and mutators

extension KBSearchResult {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(KBSearchResult.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        results: [KBSearchHit]? = nil
    ) -> KBSearchResult {
        return KBSearchResult(
            results: results ?? self.results
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - KBSearchHit
struct KBSearchHit: Codable {
    let brand: String
    let form, strengthText: String?
    let substances: [Substance]

    enum CodingKeys: String, CodingKey {
        case brand, form
        case strengthText = "strength_text"
        case substances
    }
}

// MARK: KBSearchHit convenience initializers and mutators

extension KBSearchHit {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(KBSearchHit.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        brand: String? = nil,
        form: String?? = nil,
        strengthText: String?? = nil,
        substances: [Substance]? = nil
    ) -> KBSearchHit {
        return KBSearchHit(
            brand: brand ?? self.brand,
            form: form ?? self.form,
            strengthText: strengthText ?? self.strengthText,
            substances: substances ?? self.substances
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Corpul pentru POST /v1/patients și PATCH /v1/patients/{id} (la PATCH toate câmpurile sunt
/// opționale).
// MARK: - PatientCreate
struct PatientCreate: Codable {
    let anchors: Anchors?
    let birthYear: Int
    let caregiverName: String?
    let name: String

    enum CodingKeys: String, CodingKey {
        case anchors
        case birthYear = "birth_year"
        case caregiverName = "caregiver_name"
        case name
    }
}

// MARK: PatientCreate convenience initializers and mutators

extension PatientCreate {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PatientCreate.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        anchors: Anchors?? = nil,
        birthYear: Int? = nil,
        caregiverName: String?? = nil,
        name: String? = nil
    ) -> PatientCreate {
        return PatientCreate(
            anchors: anchors ?? self.anchors,
            birthYear: birthYear ?? self.birthYear,
            caregiverName: caregiverName ?? self.caregiverName,
            name: name ?? self.name
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Anchors
struct Anchors: Codable {
    let bed, breakfast, dinner, lunch: String
    let wake: String
}

// MARK: Anchors convenience initializers and mutators

extension Anchors {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Anchors.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bed: String? = nil,
        breakfast: String? = nil,
        dinner: String? = nil,
        lunch: String? = nil,
        wake: String? = nil
    ) -> Anchors {
        return Anchors(
            bed: bed ?? self.bed,
            breakfast: breakfast ?? self.breakfast,
            dinner: dinner ?? self.dinner,
            lunch: lunch ?? self.lunch,
            wake: wake ?? self.wake
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PatientCreated
struct PatientCreated: Codable {
    let id: String
    let patient: Patient
    let patientToken: String

    enum CodingKeys: String, CodingKey {
        case id, patient
        case patientToken = "patient_token"
    }
}

// MARK: PatientCreated convenience initializers and mutators

extension PatientCreated {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PatientCreated.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        id: String? = nil,
        patient: Patient? = nil,
        patientToken: String? = nil
    ) -> PatientCreated {
        return PatientCreated(
            id: id ?? self.id,
            patient: patient ?? self.patient,
            patientToken: patientToken ?? self.patientToken
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Profilul pacientului și ancorele zilei (5.7).
// MARK: - Patient
struct Patient: Codable {
    let anchors: Anchors
    let birthYear: Int
    /// numele aparținătorului, folosit în texte („Am anunțat-o pe Ana”)
    let caregiverName: String?
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case anchors
        case birthYear = "birth_year"
        case caregiverName = "caregiver_name"
        case id, name
    }
}

// MARK: Patient convenience initializers and mutators

extension Patient {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Patient.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        anchors: Anchors? = nil,
        birthYear: Int? = nil,
        caregiverName: String?? = nil,
        id: String? = nil,
        name: String? = nil
    ) -> Patient {
        return Patient(
            anchors: anchors ?? self.anchors,
            birthYear: birthYear ?? self.birthYear,
            caregiverName: caregiverName ?? self.caregiverName,
            id: id ?? self.id,
            name: name ?? self.name
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Programul unei zile, calculat de solver. Plan, secțiunea 5.4.
// MARK: - Schedule
struct Schedule: Codable {
    let anchors: Anchors
    let date: String
    let moments: [Moment]
    let solver: Solver
    let unsatisfied: [Unsatisfied]
}

// MARK: Schedule convenience initializers and mutators

extension Schedule {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Schedule.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        anchors: Anchors? = nil,
        date: String? = nil,
        moments: [Moment]? = nil,
        solver: Solver? = nil,
        unsatisfied: [Unsatisfied]? = nil
    ) -> Schedule {
        return Schedule(
            anchors: anchors ?? self.anchors,
            date: date ?? self.date,
            moments: moments ?? self.moments,
            solver: solver ?? self.solver,
            unsatisfied: unsatisfied ?? self.unsatisfied
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Moment
struct Moment: Codable {
    let doses: [DoseElement]
    let label: String
    let time: String
}

// MARK: Moment convenience initializers and mutators

extension Moment {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Moment.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        doses: [DoseElement]? = nil,
        label: String? = nil,
        time: String? = nil
    ) -> Moment {
        return Moment(
            doses: doses ?? self.doses,
            label: label ?? self.label,
            time: time ?? self.time
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - DoseElement
struct DoseElement: Codable {
    let instruction: String
    let medid: String
    let qty: Double
    let reasons: [String]

    enum CodingKeys: String, CodingKey {
        case instruction
        case medid = "med_id"
        case qty, reasons
    }
}

// MARK: DoseElement convenience initializers and mutators

extension DoseElement {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DoseElement.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        instruction: String? = nil,
        medid: String? = nil,
        qty: Double? = nil,
        reasons: [String]? = nil
    ) -> DoseElement {
        return DoseElement(
            instruction: instruction ?? self.instruction,
            medid: medid ?? self.medid,
            qty: qty ?? self.qty,
            reasons: reasons ?? self.reasons
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Solver
struct Solver: Codable {
    let momentsCount: Int
    let version: String

    enum CodingKeys: String, CodingKey {
        case momentsCount = "moments_count"
        case version
    }
}

// MARK: Solver convenience initializers and mutators

extension Solver {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Solver.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        momentsCount: Int? = nil,
        version: String? = nil
    ) -> Solver {
        return Solver(
            momentsCount: momentsCount ?? self.momentsCount,
            version: version ?? self.version
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Unsatisfied
struct Unsatisfied: Codable {
    let medids: [String]
    let reason, rule: String

    enum CodingKeys: String, CodingKey {
        case medids = "med_ids"
        case reason, rule
    }
}

// MARK: Unsatisfied convenience initializers and mutators

extension Unsatisfied {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Unsatisfied.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        medids: [String]? = nil,
        reason: String? = nil,
        rule: String? = nil
    ) -> Unsatisfied {
        return Unsatisfied(
            medids: medids ?? self.medids,
            reason: reason ?? self.reason,
            rule: rule ?? self.rule
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ShareLink
struct ShareLink: Codable {
    let expiresAt: Date
    let shareToken: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
        case shareToken = "share_token"
        case url
    }
}

// MARK: ShareLink convenience initializers and mutators

extension ShareLink {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ShareLink.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        expiresAt: Date? = nil,
        shareToken: String? = nil,
        url: String? = nil
    ) -> ShareLink {
        return ShareLink(
            expiresAt: expiresAt ?? self.expiresAt,
            shareToken: shareToken ?? self.shareToken,
            url: url ?? self.url
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Corpul pentru POST /what-if: fie query (text liber, ex. „algocalmin”), fie med.
// MARK: - WhatIfRequest
struct WhatIfRequest: Codable {
    let med: MedicationItem?
    let query: String?
}

// MARK: WhatIfRequest convenience initializers and mutators

extension WhatIfRequest {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(WhatIfRequest.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        med: MedicationItem?? = nil,
        query: String?? = nil
    ) -> WhatIfRequest {
        return WhatIfRequest(
            med: med ?? self.med,
            query: query ?? self.query
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - WhatIfResult
struct WhatIfResult: Codable {
    /// medicamentul găsit pentru query; null dacă nu s-a găsit
    let matched: MedicationItem?
    let newAlerts: [Alert]

    enum CodingKeys: String, CodingKey {
        case matched
        case newAlerts = "new_alerts"
    }
}

// MARK: WhatIfResult convenience initializers and mutators

extension WhatIfResult {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(WhatIfResult.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        matched: MedicationItem?? = nil,
        newAlerts: [Alert]? = nil
    ) -> WhatIfResult {
        return WhatIfResult(
            matched: matched ?? self.matched,
            newAlerts: newAlerts ?? self.newAlerts
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        encoder.dateEncodingStrategy = .iso8601
    }
    return encoder
}
