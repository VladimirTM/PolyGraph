import Foundation
import Testing
@testable import PolyGraph

@MainActor
private func demoSchedule() throws -> Schedule {
    try JSONCoding.decoder.decode(Schedule.self, from: ContractFiles.data("fixtures/expected_schedule.json"))
}

@MainActor
private func bucharest() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
    return calendar
}

/// T-A4-01: momentul curent pe programul demo (07:00, 07:30, 08:00, 13:00, 19:00).
@MainActor
struct CurrentMomentTests {
    private func current(at clock: String, done: Set<String> = []) throws -> String? {
        let schedule = try demoSchedule()
        let now = try #require(SeniorDay.minutes(clock))
        return SeniorDay.currentMoment(in: schedule.moments, nowMinutes: now) { done.contains($0.time) }?.time
    }

    // T-A4-01
    @Test func currentMomentForSixHoursOfTheDay() throws {
        let cases: [(clock: String, expected: String?)] = [
            ("05:30", "07:00"),  // înainte de trezire: următorul moment
            ("07:10", "07:00"),  // la scurt timp după ora momentului
            ("10:30", "13:00"),  // între momente: micul dejun a trecut de peste 2 h
            ("14:45", "13:00"),  // prânzul neconfirmat, încă în cele 2 h
            ("20:30", "19:00"),  // cina neconfirmată, încă în cele 2 h
            ("23:30", nil),  // după culcare: nimic de luat
        ]
        for item in cases {
            #expect(try current(at: item.clock) == item.expected, "la \(item.clock)")
        }
    }

    @Test func aConfirmedMomentMakesRoomForTheNextOne() throws {
        #expect(try current(at: "07:10", done: ["07:00"]) == "07:30")
        #expect(try current(at: "09:00", done: ["07:00"]) == "07:30")
        #expect(try current(at: "20:00", done: ["07:00", "07:30", "08:00", "13:00", "19:00"]) == nil)
    }

    @Test func buttonsAppearHalfAnHourBefore() throws {
        let lunch = try #require(try demoSchedule().moments.first { $0.time == "13:00" })
        let early = try #require(SeniorDay.minutes("12:20"))
        let onTime = try #require(SeniorDay.minutes("12:30"))
        #expect(SeniorDay.isDue(lunch, nowMinutes: early) == false)
        #expect(SeniorDay.isDue(lunch, nowMinutes: onTime))
    }
}

/// T-A4-02: „Am luat” de două ori → un singur set de POST /doses; „Anulează” trimite `pending`.
@MainActor
struct DoseLogTests {
    private final class Recorder {
        var doses: [Dose] = []
    }

    private final class FakeUptime {
        var value: TimeInterval = 100
    }

    private let day = "2026-11-14"

    private func makeLog(_ recorder: Recorder, _ uptime: FakeUptime) -> DoseLog {
        let defaults = UserDefaults(suiteName: "pg.test.\(UUID().uuidString)") ?? .standard
        let guarded = GuardedAction(interval: GuardedAction.seniorInterval, uptime: { uptime.value })
        return DoseLog(defaults: defaults, guarded: guarded) { recorder.doses.append($0) }
    }

    /// 07:30: Omeprazol + Amlodipină
    private func morning() throws -> Moment {
        try #require(try demoSchedule().moments.first { $0.time == "07:30" })
    }

    // T-A4-02
    @Test func doubleTapWithin300msSendsOneSetOfDoses() async throws {
        let recorder = Recorder()
        let uptime = FakeUptime()
        let log = makeLog(recorder, uptime)
        let moment = try morning()

        let first = log.record(.taken, moment: moment, day: day)
        uptime.value += 0.3
        let second = log.record(.taken, moment: moment, day: day)
        _ = await first?.value

        #expect(first != nil)
        #expect(second == nil)
        #expect(recorder.doses.map(\.medid) == ["med_07", "med_04"])
        #expect(recorder.doses.allSatisfy { $0.status == .taken })
        #expect(Set(recorder.doses.map(\.scheduledAt)).count == 1)
        #expect(log.momentStatus(moment, day: day) == .taken)
    }

    // T-A4-02
    @Test func undoSendsPendingAndReopensTheMoment() async throws {
        let recorder = Recorder()
        let uptime = FakeUptime()
        let log = makeLog(recorder, uptime)
        let moment = try morning()

        _ = await log.record(.taken, moment: moment, day: day)?.value
        #expect(log.undo?.time == "07:30")
        uptime.value += 2
        _ = await log.undoLast()?.value

        #expect(recorder.doses.count == 4)
        #expect(recorder.doses.suffix(2).allSatisfy { $0.status == .pending })
        #expect(recorder.doses.suffix(2).map(\.medid) == ["med_07", "med_04"])
        #expect(recorder.doses[0].scheduledAt == recorder.doses[2].scheduledAt)
        #expect(log.momentStatus(moment, day: day) == .open)
        #expect(log.undo == nil)
    }

    @Test func afterUndoTheGuardStillHoldsForOneSecond() async throws {
        let recorder = Recorder()
        let uptime = FakeUptime()
        let log = makeLog(recorder, uptime)
        let moment = try morning()

        _ = await log.record(.taken, moment: moment, day: day)?.value
        log.undoLast()
        uptime.value += 0.5
        #expect(log.record(.taken, moment: moment, day: day) == nil)
        uptime.value += 1.2
        let again = log.record(.skipped, moment: moment, day: day)
        _ = await again?.value
        #expect(again != nil)
        #expect(log.momentStatus(moment, day: day) == .skipped)
    }

    @Test func confirmationsSurviveARestart() async throws {
        let suite = "pg.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let moment = try morning()
        let log = DoseLog(defaults: defaults)
        _ = await log.record(.taken, moment: moment, day: day)?.value

        let reopened = DoseLog(defaults: defaults)
        #expect(reopened.momentStatus(moment, day: day) == .taken)
    }
}

@MainActor
struct SeniorWordsTests {
    @Test func scheduledAtUsesTheLocalDay() throws {
        let date = try #require(SeniorDay.scheduledAt(day: "2026-11-14", time: "07:00", calendar: bucharest()))
        #expect(JSONCoding.formatISO8601(date).hasPrefix("2026-11-14T05:00:00"))
    }

    @Test func quantityInWords() {
        #expect(SeniorDay.quantityWords(1, form: "comprimate") == "o pastilă")
        #expect(SeniorDay.quantityWords(0.5, form: "comprimate") == "jumătate de pastilă")
        #expect(SeniorDay.quantityWords(2, form: "comprimate filmate") == "două pastile")
        #expect(SeniorDay.quantityWords(1, form: "capsule gastrorezistente") == "o capsulă")
        #expect(SeniorDay.quantityWords(1.5, form: nil) == "o pastilă și jumătate")
    }

    @Test func spokenNextMoment() throws {
        let lunch = try #require(try demoSchedule().moments.first { $0.time == "13:00" })
        #expect(SeniorDay.afterAction(.taken, next: lunch) == "Foarte bine. Următoarele pastile sunt la ora 13.")
        #expect(SeniorDay.afterAction(.skipped, next: nil) == "Am notat. Ați terminat pastilele de azi.")
        #expect(SeniorDay.spokenClock("07:30") == "ora 7 și 30")
    }

    @Test func remindersForTodayAndTomorrowSkipDoneAndPastMoments() throws {
        let calendar = bucharest()
        let now = try #require(SeniorDay.scheduledAt(day: "2026-11-14", time: "07:10", calendar: calendar))
        let planned = Reminders.plan(
            schedule: try demoSchedule(), names: { $0 }, isDone: { $0.time == "07:30" }, now: now,
            calendar: calendar)
        #expect(planned.map(\.id) == [
            "pg.moment.2026-11-14T08:00",
            "pg.moment.2026-11-14T13:00",
            "pg.moment.2026-11-14T19:00",
            "pg.moment.2026-11-15T07:00",
            "pg.moment.2026-11-15T07:30",
            "pg.moment.2026-11-15T08:00",
            "pg.moment.2026-11-15T13:00",
            "pg.moment.2026-11-15T19:00",
        ])
        #expect(planned.first?.title == "La micul dejun")
        #expect(planned.last?.body == "med_01, med_02, med_03, med_08")
    }
}

// MARK: - Q3F1

/// Q3-04: „Ați terminat” doar când chiar s-a confirmat tot.
@MainActor
struct DayEndTests {
    @Test func emptyAllDoneAndNothingNow() throws {
        let moments = try demoSchedule().moments
        #expect(SeniorDay.dayEnd([], isDone: { _ in true }) == .empty)
        #expect(SeniorDay.dayEnd(moments, isDone: { _ in true }) == .allDone)
        // 23:59 fără nicio confirmare
        #expect(SeniorDay.dayEnd(moments, isDone: { _ in false }) == .nothingNow)
        #expect(SeniorDay.dayEnd(moments, isDone: { $0.time != "07:00" }) == .nothingNow)
    }

    @Test func wordsOnScreenAndInVoiceMatch() throws {
        let moments = try demoSchedule().moments
        #expect(SeniorDay.dayEndTitle(.empty) == "Nu aveți pastile în program.")
        #expect(SeniorDay.dayEndTitle(.nothingNow) == "Pentru azi nu mai e nimic de luat acum.")
        #expect(SeniorDay.momentSpeech(nil, doseLines: [], due: false, dayEnd: .nothingNow)
            == "Pentru azi nu mai e nimic de luat acum.")
        #expect(SeniorDay.momentSpeech(nil, doseLines: [], due: false, dayEnd: .empty)
            == "Nu aveți pastile în program.")
        #expect(SeniorDay.afterAction(.taken, next: nil, allDone: false)
            == "Foarte bine. Pentru azi nu mai e nimic de luat acum.")
        #expect(SeniorDay.tomorrowLine(moments) == "Mâine, primele sunt la ora 07:00.")
        #expect(SeniorDay.tomorrowLine([]) == nil)
    }
}

/// Q3-03: „Anulează” apare sub degetul care a apăsat „Am sărit” și ignoră atingerile din primele 800 ms.
@MainActor
struct UndoGuardTests {
    private final class FakeUptime {
        var value: TimeInterval = 100
    }

    @Test func armedGuardIgnoresTheTapsThatArriveWithTheBanner() {
        let uptime = FakeUptime()
        let guarded = GuardedAction(interval: UndoBanner.armDelay, uptime: { uptime.value })
        var undone = 0
        guarded.arm()
        uptime.value += 0.1
        #expect(guarded({ undone += 1 }) == false)
        uptime.value += 0.5
        #expect(guarded({ undone += 1 }) == false)
        uptime.value += 0.3
        #expect(guarded({ undone += 1 }) == true)
        #expect(undone == 1)
    }
}

/// T-Q3F1-05: o confirmare care n-a plecat rămâne după repornire și se retrimite aceeași.
@MainActor
struct DoseQueueTests {
    private final class Recorder {
        var doses: [Dose] = []
    }

    private let day = "2026-11-14"

    private func morning() throws -> Moment {
        try #require(try demoSchedule().moments.first { $0.time == "07:30" })
    }

    @Test func failedSendIsRetriedAfterARestart() async throws {
        let defaults = try #require(UserDefaults(suiteName: "pg.test.\(UUID().uuidString)"))
        let moment = try morning()
        let offline = DoseLog(defaults: defaults, retryDelay: .seconds(3600)) { _ in
            throw APIError.network(URLError(.notConnectedToInternet))
        }
        _ = await offline.record(.taken, moment: moment, day: day)?.value
        #expect(offline.lastError != nil)
        #expect(offline.unsentCount == 2)

        let recorder = Recorder()
        let reopened = DoseLog(defaults: defaults, retryDelay: .seconds(3600)) { recorder.doses.append($0) }
        #expect(reopened.unsentCount == 2)
        _ = await reopened.retryUnsent()?.value

        #expect(recorder.doses.map(\.medid) == ["med_07", "med_04"])
        #expect(recorder.doses.allSatisfy { $0.status == .taken })
        let at = try #require(SeniorDay.scheduledAt(day: day, time: "07:30"))
        #expect(recorder.doses.map(\.scheduledAt) == [at, at])
        #expect(reopened.unsentCount == 0)
        #expect(reopened.lastError == nil)
        // coada goală nu mai rămâne pe disc
        #expect(DoseLog(defaults: defaults).unsentCount == 0)
    }

    @Test func aRejectedDoseDoesNotBlockTheQueue() async throws {
        let defaults = try #require(UserDefaults(suiteName: "pg.test.\(UUID().uuidString)"))
        let moment = try morning()
        let recorder = Recorder()
        let log = DoseLog(defaults: defaults, retryDelay: .seconds(3600)) { dose in
            if dose.medid == "med_07" { throw APIError.http(status: 404, detail: nil) }
            recorder.doses.append(dose)
        }
        _ = await log.record(.taken, moment: moment, day: day)?.value
        #expect(recorder.doses.map(\.medid) == ["med_04"])
        #expect(log.unsentCount == 0)
        #expect(log.lastError == nil)
    }
}

/// T-Q3F1-06: după miezul nopții, „Acum” cere programul zilei noi.
@MainActor
struct MidnightRefreshTests {
    private final class MovingClock: AppClock {
        var now: Date
        init(now: Date) { self.now = now }
    }

    private func local(_ day: String, _ time: String) throws -> Date {
        try #require(SeniorDay.scheduledAt(day: day, time: time))
    }

    @Test func afterMidnightTheScheduleIsTheNewDay() async throws {
        let responses = try StubServer.Responses(
            patient: ContractFiles.data("examples/patient.demo.json"),
            meds: ContractFiles.data("examples/medication_item.sintrom.json"),
            analysis: ContractFiles.data("examples/analysis.demo.json"),
            schedule: ContractFiles.data("fixtures/expected_schedule.json"))
        StubServer.start(responses)
        defer { StubServer.stop() }

        let defaults = try #require(UserDefaults(suiteName: "pg.test.\(UUID().uuidString)"))
        let settings = AppSettings(defaults: defaults)
        settings.baseURLString = "http://stub.polygraph.test"
        settings.signIn(patientID: "pat_demo", token: "demo-token")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubServer.self]
        let clock = MovingClock(now: try local("2026-11-14", "23:59"))
        let store = AppStore(
            settings: settings, debug: DebugEnvironment(), clock: clock,
            session: URLSession(configuration: configuration))

        await store.refreshAll()
        #expect(store.schedule?.date == "2026-11-14")
        await store.refreshIfNewDay()
        #expect(StubServer.scheduleRequests == 1)

        clock.now = try local("2026-11-15", "00:01")
        await store.refreshIfNewDay()
        #expect(store.schedule?.date == "2026-11-15")
        #expect(StubServer.scheduleRequests == 2)
    }
}

/// Serverul simulat pentru AppStore: răspunde din contracts/, iar /schedule întoarce ziua cerută.
nonisolated final class StubServer: URLProtocol {
    nonisolated struct Responses {
        let patient: Data
        let meds: Data
        let analysis: Data
        let schedule: Data
    }

    nonisolated(unsafe) private static var responses: Responses?
    nonisolated(unsafe) private(set) static var scheduleRequests = 0

    static func start(_ responses: Responses) {
        self.responses = responses
        scheduleRequests = 0
    }

    static func stop() {
        responses = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body) = Self.reply(to: request)
        let url = request.url ?? URL(fileURLWithPath: "/")
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func reply(to request: URLRequest) -> (Int, Data) {
        guard let responses, let url = request.url else { return (500, Data()) }
        let path = url.path()
        if path.hasSuffix("/schedule") {
            scheduleRequests += 1
            let day = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "date" }?.value
            guard var json = try? JSONSerialization.jsonObject(with: responses.schedule) as? [String: Any] else {
                return (500, Data())
            }
            if let day { json["date"] = day }
            return (200, (try? JSONSerialization.data(withJSONObject: json)) ?? Data())
        }
        if path.hasSuffix("/meds") { return (200, Data("[".utf8) + responses.meds + Data("]".utf8)) }
        if path.hasSuffix("/analysis") { return (200, responses.analysis) }
        if path.hasSuffix("/doses") { return (500, Data()) }
        if path.contains("/v1/patients/") { return (200, responses.patient) }
        return (404, Data())
    }
}
