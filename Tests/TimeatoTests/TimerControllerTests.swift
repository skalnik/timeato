import XCTest
import TimeatoCore
@testable import TimeatoKit

/// Records the calls from the controller. It does not show notifications.
@MainActor
private final class FakeNotifications: NotificationScheduling {
    enum Call: Equatable {
        case requestAuthorization
        case schedule(Phase, TimeInterval, playSound: Bool)
        case cancel
        case postNow(Phase, playSound: Bool)
    }

    var calls: [Call] = []

    func requestAuthorization() { calls.append(.requestAuthorization) }

    func schedule(for phase: Phase, after interval: TimeInterval, playSound: Bool) {
        calls.append(.schedule(phase, interval, playSound: playSound))
    }

    func cancel() { calls.append(.cancel) }

    func postNow(for phase: Phase, playSound: Bool) {
        calls.append(.postNow(phase, playSound: playSound))
    }
}

@MainActor
final class TimerControllerTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var currentDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private var notifications: FakeNotifications!

    // The async forms of setUp and tearDown run on the main actor.
    // Thus they can change the properties of this class.
    override func setUp() async throws {
        try await super.setUp()
        // Each test uses its own suite. Tests do not share settings.
        suiteName = "com.skalnik.timeato.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        notifications = FakeNotifications()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        notifications = nil
        try await super.tearDown()
    }

    private func makeController() -> TimerController {
        TimerController(
            defaults: defaults,
            clock: { [unowned self] in self.currentDate },
            notifications: notifications
        )
    }

    // MARK: - Settings

    func testDefaultsWhenStoreIsEmpty() {
        let controller = makeController()
        XCTAssertEqual(controller.workMinutes, 25)
        XCTAssertEqual(controller.breakMinutes, 5)
        XCTAssertTrue(controller.playSound)
        XCTAssertEqual(controller.timeText, "25:00")
    }

    func testLoadsSettingsFromDefaults() {
        defaults.set(50, forKey: "workMinutes")
        defaults.set(10, forKey: "breakMinutes")
        defaults.set(false, forKey: "playSound")
        let controller = makeController()
        XCTAssertEqual(controller.workMinutes, 50)
        XCTAssertEqual(controller.breakMinutes, 10)
        XCTAssertFalse(controller.playSound)
        XCTAssertEqual(controller.timeText, "50:00")
    }

    func testIgnoresStoredValuesThatAreNotPresets() {
        defaults.set(7, forKey: "workMinutes")
        defaults.set(0, forKey: "breakMinutes")
        let controller = makeController()
        XCTAssertEqual(controller.workMinutes, 25)
        XCTAssertEqual(controller.breakMinutes, 5)
        XCTAssertEqual(controller.timeText, "25:00")
    }

    func testIgnoresStoredValuesOfTheWrongType() {
        defaults.set("long", forKey: "workMinutes")
        defaults.set(-5, forKey: "breakMinutes")
        let controller = makeController()
        XCTAssertEqual(controller.workMinutes, 25)
        XCTAssertEqual(controller.breakMinutes, 5)
    }

    func testWorkMinutesChangePersistsAndUpdatesTimeText() {
        let controller = makeController()
        controller.workMinutes = 45
        XCTAssertEqual(defaults.integer(forKey: "workMinutes"), 45)
        XCTAssertEqual(controller.timeText, "45:00")
    }

    func testBreakMinutesChangePersists() {
        let controller = makeController()
        controller.breakMinutes = 15
        XCTAssertEqual(defaults.integer(forKey: "breakMinutes"), 15)
        controller.skip()
        XCTAssertEqual(controller.timeText, "15:00")
    }

    func testPlaySoundChangePersists() {
        let controller = makeController()
        controller.playSound = false
        XCTAssertEqual(defaults.object(forKey: "playSound") as? Bool, false)
    }

    func testWorkMinutesChangeWhileRunningKeepsEndDate() {
        let controller = makeController()
        controller.primaryAction()
        let before = controller.engine.state
        XCTAssertEqual(before, .running(endDate: currentDate + 25 * 60))

        controller.workMinutes = 15
        XCTAssertEqual(controller.engine.state, before)
        XCTAssertEqual(controller.timeText, "25:00")

        // Stop the tick loop at the end of the test.
        controller.reset()
        XCTAssertEqual(controller.timeText, "15:00")
    }

    // MARK: - Titles and images

    func testPrimaryActionTitleCycles() {
        let controller = makeController()
        XCTAssertEqual(controller.primaryActionTitle, "Start")
        XCTAssertEqual(controller.primaryActionSymbol, "play.fill")
        controller.primaryAction()
        XCTAssertEqual(controller.primaryActionTitle, "Pause")
        XCTAssertEqual(controller.primaryActionSymbol, "pause.fill")
        controller.primaryAction()
        XCTAssertEqual(controller.primaryActionTitle, "Resume")
        XCTAssertEqual(controller.primaryActionSymbol, "play.fill")
        controller.primaryAction()
        XCTAssertEqual(controller.primaryActionTitle, "Pause")
        XCTAssertEqual(controller.primaryActionSymbol, "pause.fill")
        controller.reset()
    }

    func testResetReturnsToStart() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 60
        controller.reset()
        XCTAssertEqual(controller.primaryActionTitle, "Start")
        XCTAssertEqual(controller.phase, .work)
        XCTAssertEqual(controller.timeText, "25:00")
    }

    func testSkipTitleAndImagePerPhase() {
        let controller = makeController()
        XCTAssertEqual(controller.skipTitle, "Skip to Break")
        XCTAssertEqual(controller.phaseImage, .tomato)

        controller.skip()
        XCTAssertEqual(controller.phase, .break)
        XCTAssertEqual(controller.skipTitle, "Skip to Work")
        XCTAssertEqual(controller.phaseImage, .coolTomato)
        XCTAssertEqual(controller.timeText, "05:00")

        controller.skip()
        XCTAssertEqual(controller.skipTitle, "Skip to Break")
        XCTAssertEqual(controller.phaseImage, .tomato)
    }

    func testPauseFreezesTimeText() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 90
        controller.primaryAction()
        XCTAssertEqual(controller.timeText, "23:30")
        currentDate += 1000
        controller.primaryAction()
        XCTAssertEqual(controller.timeText, "23:30")
        controller.reset()
    }

    // MARK: - Actions after the end date

    func testPrimaryActionAfterEndFinishesPhaseAndDoesNotStartNext() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 25 * 60 + 10

        controller.primaryAction()
        XCTAssertEqual(controller.engine.state, .idle)
        XCTAssertEqual(controller.phase, .break)
        XCTAssertEqual(controller.primaryActionTitle, "Start")
        XCTAssertEqual(controller.timeText, "05:00")
    }

    func testPrimaryActionAtExactEndFinishesPhase() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 25 * 60

        controller.primaryAction()
        XCTAssertEqual(controller.engine.state, .idle)
        XCTAssertEqual(controller.phase, .break)
    }

    func testSkipAfterEndFinishesPhaseThenSkips() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 25 * 60 + 10

        // The work phase finishes first and loads the break. Skip then loads work.
        controller.skip()
        XCTAssertEqual(controller.engine.state, .idle)
        XCTAssertEqual(controller.phase, .work)
    }

    func testResetAfterEndKeepsTheNextPhase() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 25 * 60 + 10

        controller.reset()
        XCTAssertEqual(controller.engine.state, .idle)
        XCTAssertEqual(controller.phase, .break)
        XCTAssertEqual(controller.timeText, "05:00")
    }

    // MARK: - Ticking

    func testTickDoesNotChangeTheControllerBeforeThePhaseEnd() {
        let controller = makeController()
        controller.primaryAction()
        var changes = 0
        let cancellable = controller.objectWillChange.sink { changes += 1 }
        currentDate += 5

        controller.refresh(at: currentDate)
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(controller.timeText, "24:55")
        cancellable.cancel()
        controller.reset()
    }

    // MARK: - Phase end notification

    func testInitAsksForAuthorization() {
        _ = makeController()
        XCTAssertEqual(notifications.calls, [.requestAuthorization])
    }

    func testStartSchedulesNotification() {
        let controller = makeController()
        controller.primaryAction()
        XCTAssertEqual(notifications.calls.last, .schedule(.work, 25 * 60, playSound: true))
        controller.reset()
    }

    func testPauseCancelsNotification() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 90
        controller.primaryAction()
        XCTAssertEqual(notifications.calls.last, .cancel)
    }

    func testResumeSchedulesNotificationForRemainingTime() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 90
        controller.primaryAction()
        currentDate += 1000
        controller.primaryAction()
        XCTAssertEqual(notifications.calls.last, .schedule(.work, 25 * 60 - 90, playSound: true))
        controller.reset()
    }

    func testResetCancelsNotification() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 60
        controller.reset()
        XCTAssertEqual(notifications.calls.last, .cancel)
    }

    func testSkipCancelsNotification() {
        let controller = makeController()
        controller.primaryAction()
        controller.skip()
        XCTAssertEqual(notifications.calls.last, .cancel)
    }

    func testPlaySoundChangeWhileRunningSchedulesAgain() {
        let controller = makeController()
        controller.primaryAction()
        currentDate += 60
        controller.playSound = false
        XCTAssertEqual(notifications.calls.last, .schedule(.work, 24 * 60, playSound: false))
        controller.reset()
    }

    func testOnTimePhaseEndDoesNotPostSecondNotification() {
        let controller = makeController()
        controller.primaryAction()
        notifications.calls = []
        currentDate += 25 * 60 + 1

        controller.primaryAction()
        XCTAssertEqual(controller.phase, .break)
        XCTAssertEqual(notifications.calls, [])
    }

    func testLatePhaseEndCancelsAndPostsNotification() {
        let controller = makeController()
        controller.primaryAction()
        notifications.calls = []
        currentDate += 25 * 60 + 3

        controller.primaryAction()
        XCTAssertEqual(controller.phase, .break)
        XCTAssertEqual(notifications.calls, [.cancel, .postNow(.work, playSound: true)])
    }
}
