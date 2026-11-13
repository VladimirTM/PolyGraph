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
