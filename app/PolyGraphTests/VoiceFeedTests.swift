import Foundation
import Testing
@testable import PolyGraph

/// T-A5-01: detectorul de liniște.
@MainActor
struct SilenceDetectorTests {
    /// Trimite `level` la fiecare 100 ms între `from` și `to` (secunde); întoarce prima decizie de oprire.
    private func run(
        _ detector: inout SilenceDetector, level: Float, from: TimeInterval, to: TimeInterval
    ) -> (SilenceDetector.Decision, TimeInterval)? {
        var time = from
        while time < to - 0.0001 {
            let decision = detector.feed(level: level, at: time)
            if decision != .listen { return (decision, time) }
            time += 0.1
        }
        return nil
    }

    // T-A5-01
    @Test func stopsAfterTwoSecondsOfSilenceOnceSomethingWasSaid() throws {
        var detector = SilenceDetector()
        let r1 = run(&detector, level: 0.6, from: 0, to: 1.5)
        #expect(r1 == nil)
        let result = run(&detector, level: 0.05, from: 1.5, to: 5)
        let stop = try #require(result)
        #expect(stop.0 == .stopSilence)
        #expect(abs(stop.1 - 3.5) < 0.15)
    }

    // T-A5-01
    @Test func aOneSecondPauseDoesNotStop() {
        var detector = SilenceDetector()
        let r2 = run(&detector, level: 0.6, from: 0, to: 1)
        #expect(r2 == nil)
        let r3 = run(&detector, level: 0.05, from: 1, to: 2)
        #expect(r3 == nil)
        let r4 = run(&detector, level: 0.6, from: 2, to: 3)
        #expect(r4 == nil)
        let r5 = run(&detector, level: 0.05, from: 3, to: 4)
        #expect(r5 == nil)
    }

    // T-A5-01
    @Test func neverStopsOnSilenceBeforeAnythingWasSaid() {
        var detector = SilenceDetector()
        let r6 = run(&detector, level: 0.01, from: 0, to: 30)
        #expect(r6 == nil)
        #expect(detector.hasSpoken == false)
    }

    @Test func stopsAtTheTimeLimit() throws {
        var detector = SilenceDetector()
        let result = run(&detector, level: 0.6, from: 0, to: 70)
        let stop = try #require(result)
        #expect(stop.0 == .stopLimit)
        #expect(abs(stop.1 - 60) < 0.15)
    }

    /// În zgomotul sălii nivelul nu mai scade; fără cuvinte noi 4 s, se oprește oricum.
    @Test func noisyRoomStopsWhenWordsStop() throws {
        var detector = SilenceDetector()
        detector.noteWords(at: 0.5)
        let result = run(&detector, level: 0.6, from: 0, to: 10)
        let stop = try #require(result)
        #expect(stop.0 == .stopSilence)
        #expect(abs(stop.1 - 4.5) < 0.15)
    }
}

/// T-A5-02: feed-ul nu dublează evenimentele la polling repetat.
@MainActor
struct FeedModelTests {
    private final class Recorder {
        var notified: [String] = []
    }

    private func event(
        _ id: String, minute: Int, type: FeedEventType = .doseMissed, severity: Severity? = nil
    ) -> FeedEvent {
        FeedEvent(
            alertid: nil, at: Date(timeIntervalSince1970: 1_794_600_000 + Double(minute * 60)), body: "corp",
            checkinid: type == .checkin ? "ci_\(id)" : nil, id: "ev_\(id)", medids: [], severity: severity,
            title: "Maria a raportat: amețeală, vânătăi", type: type)
    }

    // T-A5-02
    @Test func repeatedPollingDeduplicatesById() {
        let recorder = Recorder()
        let feed = FeedModel(notify: { recorder.notified.append($0.id) })
        let history = [event("a", minute: 1), event("b", minute: 2)]

        feed.receive(history)
        feed.receive(history)
        feed.receive([event("b", minute: 2)])

        #expect(feed.events.map(\.id) == ["ev_b", "ev_a"])
        #expect(recorder.notified.isEmpty)
    }

    @Test func historyIsSilentButNewSeriousEventsNotifyOnce() {
        let recorder = Recorder()
        let feed = FeedModel(notify: { recorder.notified.append($0.id) })
        feed.receive([event("old", minute: 1, type: .checkin)])
        #expect(recorder.notified.isEmpty)

        let checkIn = event("new", minute: 5, type: .checkin, severity: .major)
        feed.receive([checkIn, event("dose", minute: 4)])
        feed.receive([checkIn])

        #expect(feed.events.map(\.id) == ["ev_new", "ev_dose", "ev_old"])
        #expect(recorder.notified == ["ev_new"])
        #expect(feed.alarmCount == 1)
    }

    @Test func newEventsWaitWhileTheListIsScrolled() {
        let feed = FeedModel()
        feed.receive([event("a", minute: 1)])
        feed.setAtTop(false)
        feed.receive([event("b", minute: 2), event("c", minute: 3)])

        #expect(feed.events.map(\.id) == ["ev_a"])
        #expect(feed.pendingNew.map(\.id) == ["ev_c", "ev_b"])

        feed.setAtTop(true)
        #expect(feed.events.map(\.id) == ["ev_c", "ev_b", "ev_a"])
        #expect(feed.pendingNew.isEmpty)
    }

    @Test func pollAsksOnlyForWhatIsNewer() async {
        var asked: [Date?] = []
        let first = event("a", minute: 1)
        let feed = FeedModel(fetch: { since in
            asked.append(since)
            return since == nil ? [first] : []
        })
        await feed.poll()
        await feed.poll()
        #expect(asked == [nil, first.at])
    }

    @Test func checkInTitleSplitsIntoSymptoms() {
        let checkIn = event("x", minute: 1, type: .checkin)
        #expect(checkIn.shortTitle == "Maria a raportat")
        #expect(checkIn.symptomLabels == ["amețeală", "vânătăi"])
        #expect(FeedView.countText(3) == "3 noutăți")
        #expect(FeedView.countText(1) == "o noutate")
    }
}
