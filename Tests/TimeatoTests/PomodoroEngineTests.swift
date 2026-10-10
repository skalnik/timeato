import XCTest
import TimeatoCore

final class PomodoroEngineTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let durations = Durations(work: 25 * 60, breakTime: 5 * 60)

    // MARK: - Formatting

    func testFormatTime() {
        XCTAssertEqual(formatTime(25 * 60), "25:00")
        XCTAssertEqual(formatTime(0), "00:00")
        XCTAssertEqual(formatTime(-5), "00:00")
        XCTAssertEqual(formatTime(59), "00:59")
        XCTAssertEqual(formatTime(61), "01:01")
        XCTAssertEqual(formatTime(0.2), "00:01")
        XCTAssertEqual(formatTime(1499.5), "25:00")
        XCTAssertEqual(formatTime(100 * 60), "100:00")
    }

    // MARK: - Initial state

    func testInitialStateIsIdleWork() {
        let engine = PomodoroEngine(durations: durations)
        XCTAssertEqual(engine.phase, .work)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(now: t0), 25 * 60)
    }

    // MARK: - Transitions

    func testStartGoesToRunning() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        XCTAssertEqual(engine.state, .running(endDate: t0 + 25 * 60))
        XCTAssertEqual(engine.remaining(now: t0 + 60), 24 * 60)
    }

    func testStartWhileRunningDoesNothing() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.start(now: t0 + 100)
        XCTAssertEqual(engine.state, .running(endDate: t0 + 25 * 60))
    }

    func testPauseKeepsRemaining() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.pause(now: t0 + 90)
        XCTAssertEqual(engine.state, .paused(remaining: 25 * 60 - 90))
        // Time goes on, but the remaining time does not change.
        XCTAssertEqual(engine.remaining(now: t0 + 10_000), 25 * 60 - 90)
    }

    func testPauseWhileIdleDoesNothing() {
        var engine = PomodoroEngine(durations: durations)
        engine.pause(now: t0)
        XCTAssertEqual(engine.state, .idle)
    }

    func testResumeSetsNewEndDate() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.pause(now: t0 + 90)
        engine.resume(now: t0 + 500)
        XCTAssertEqual(engine.state, .running(endDate: t0 + 500 + 25 * 60 - 90))
        XCTAssertEqual(engine.remaining(now: t0 + 500), 25 * 60 - 90)
    }

    func testResetFromRunningLoadsFullDuration() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.reset()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.phase, .work)
        XCTAssertEqual(engine.remaining(now: t0 + 100), 25 * 60)
    }

    func testResetFromPaused() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.pause(now: t0 + 10)
        engine.reset()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(now: t0), 25 * 60)
    }

    func testSkipLoadsOtherPhase() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.skip()
        XCTAssertEqual(engine.phase, .break)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(now: t0), 5 * 60)

        engine.skip()
        XCTAssertEqual(engine.phase, .work)
        XCTAssertEqual(engine.remaining(now: t0), 25 * 60)
    }

    func testSkipFromPaused() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.pause(now: t0 + 10)
        engine.skip()
        XCTAssertEqual(engine.phase, .break)
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - Phase end

    func testTickBeforeEndReturnsNil() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        XCTAssertNil(engine.tick(now: t0 + 25 * 60 - 1))
        XCTAssertEqual(engine.state, .running(endDate: t0 + 25 * 60))
    }

    func testWorkEndLoadsBreakInIdle() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        XCTAssertEqual(engine.tick(now: t0 + 25 * 60), .phaseFinished(.work))
        XCTAssertEqual(engine.phase, .break)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(now: t0 + 25 * 60), 5 * 60)
    }

    func testBreakEndLoadsWorkInIdle() {
        var engine = PomodoroEngine(durations: durations, phase: .break)
        engine.start(now: t0)
        XCTAssertEqual(engine.tick(now: t0 + 5 * 60 + 3), .phaseFinished(.break))
        XCTAssertEqual(engine.phase, .work)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(now: t0), 25 * 60)
    }

    func testTickAfterEndReturnsEventExactlyOnce() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        // A long sleep: the first tick comes long after the end date.
        let late = t0 + 3 * 3600
        XCTAssertEqual(engine.tick(now: late), .phaseFinished(.work))
        XCTAssertNil(engine.tick(now: late))
        XCTAssertNil(engine.tick(now: late + 1))
        XCTAssertEqual(engine.phase, .break)
    }

    func testTickWhilePausedPastEndDoesNothing() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.pause(now: t0 + 10)
        XCTAssertNil(engine.tick(now: t0 + 10_000))
        XCTAssertEqual(engine.state, .paused(remaining: 25 * 60 - 10))
    }

    func testRemainingNeverNegative() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        XCTAssertEqual(engine.remaining(now: t0 + 10_000), 0)
    }

    // MARK: - Duration changes

    func testDurationChangeWhileIdleUpdatesRemaining() {
        var engine = PomodoroEngine(durations: durations)
        engine.durations.work = 50 * 60
        XCTAssertEqual(engine.remaining(now: t0), 50 * 60)
    }

    func testDurationChangeWhileRunningKeepsEndDate() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.durations.work = 15 * 60
        XCTAssertEqual(engine.state, .running(endDate: t0 + 25 * 60))
        XCTAssertEqual(engine.remaining(now: t0), 25 * 60)

        // The next run uses the new duration.
        engine.reset()
        XCTAssertEqual(engine.remaining(now: t0), 15 * 60)
    }

    func testDurationChangeWhilePausedKeepsRemaining() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.pause(now: t0 + 60)
        engine.durations.work = 45 * 60
        XCTAssertEqual(engine.remaining(now: t0 + 60), 24 * 60)
    }

    // MARK: - Skip and full cycle

    func testSkipFromRunningStopsTimer() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        engine.skip()
        XCTAssertEqual(engine.phase, .break)
        XCTAssertEqual(engine.state, .idle)
        // A tick after the old end date does not send an event.
        XCTAssertNil(engine.tick(now: t0 + 25 * 60 + 1))
        XCTAssertEqual(engine.phase, .break)
    }

    func testFullWorkBreakWorkCycle() {
        var engine = PomodoroEngine(durations: durations)
        engine.start(now: t0)
        XCTAssertNil(engine.tick(now: t0 + 600))

        let workEnd = t0 + 25 * 60
        XCTAssertEqual(engine.tick(now: workEnd), .phaseFinished(.work))
        XCTAssertEqual(engine.phase, .break)
        XCTAssertEqual(engine.state, .idle)

        let breakStart = workEnd + 30
        engine.start(now: breakStart)
        XCTAssertEqual(engine.state, .running(endDate: breakStart + 5 * 60))
        XCTAssertNil(engine.tick(now: breakStart + 299))
        XCTAssertEqual(engine.tick(now: breakStart + 300), .phaseFinished(.break))
        XCTAssertEqual(engine.phase, .work)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remaining(now: breakStart + 300), 25 * 60)
    }
}
