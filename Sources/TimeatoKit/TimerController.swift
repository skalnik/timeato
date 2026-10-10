import AppKit
import Combine
import TimeatoCore

/// Holds the date of the last display refresh.
///
/// Only the menu bar label observes this object. The menu items do not.
/// Thus the change each second does not rebuild the menu.
@MainActor
public final class Ticker: ObservableObject {
    @Published public internal(set) var now: Date

    init(now: Date) {
        self.now = now
    }
}

/// The menu bar image for a phase. The view maps each value to an image.
public enum PhaseImage: Hashable, Sendable {
    /// The tomato template image from the asset catalog.
    case tomato
    /// The tomato with sunglasses template image from the asset catalog.
    case coolTomato
}

/// Connects the timer engine to the system.
///
/// The controller owns the tick loop, the settings, and the notifications.
/// While the timer runs, the controller holds a process activity. Thus
/// App Nap does not slow down the tick loop.
@MainActor
public final class TimerController: ObservableObject {
    public static let workPresets = [15, 20, 25, 30, 45, 50]
    public static let breakPresets = [5, 10, 15]

    /// If a phase ends more than this time before the refresh, the scheduled
    /// notification possibly did not go out. Then the controller posts one.
    static let lateNotificationLimit: TimeInterval = 2

    private enum Key {
        static let workMinutes = "workMinutes"
        static let breakMinutes = "breakMinutes"
        static let playSound = "playSound"
    }

    @Published private(set) var engine: PomodoroEngine
    /// The date of the last refresh. A change causes the label to update.
    public let ticker: Ticker

    @Published public var workMinutes: Int {
        didSet {
            engine.durations.work = TimeInterval(workMinutes * 60)
            defaults.set(workMinutes, forKey: Key.workMinutes)
        }
    }

    @Published public var breakMinutes: Int {
        didSet {
            engine.durations.breakTime = TimeInterval(breakMinutes * 60)
            defaults.set(breakMinutes, forKey: Key.breakMinutes)
        }
    }

    @Published public var playSound: Bool {
        didSet {
            defaults.set(playSound, forKey: Key.playSound)
            // The scheduled notification must use the new setting.
            if case .running = engine.state {
                updatePhaseEndNotification(at: clock())
            }
        }
    }

    private let defaults: UserDefaults
    private let clock: () -> Date
    private var tickTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private let notifications: any NotificationScheduling
    /// The process activity while the timer runs. See
    /// https://developer.apple.com/documentation/foundation/processinfo/beginactivity(options:reason:)
    private var activity: NSObjectProtocol?

    public convenience init() {
        self.init(defaults: .standard, clock: Date.init, notifications: NotificationScheduler())
    }

    init(
        defaults: UserDefaults,
        clock: @escaping () -> Date,
        notifications: any NotificationScheduling
    ) {
        self.defaults = defaults
        self.clock = clock
        self.notifications = notifications

        let work = Self.storedMinutes(in: defaults, forKey: Key.workMinutes, presets: Self.workPresets) ?? 25
        let rest = Self.storedMinutes(in: defaults, forKey: Key.breakMinutes, presets: Self.breakPresets) ?? 5
        workMinutes = work
        breakMinutes = rest
        playSound = defaults.object(forKey: Key.playSound) as? Bool ?? true
        engine = PomodoroEngine(durations: Durations(
            work: TimeInterval(work * 60),
            breakTime: TimeInterval(rest * 60)
        ))
        ticker = Ticker(now: clock())

        notifications.requestAuthorization()
        observeWake()
    }

    /// Returns the stored value only if it is one of the presets.
    /// The menu cannot show other values.
    private static func storedMinutes(in defaults: UserDefaults, forKey key: String, presets: [Int]) -> Int? {
        guard let minutes = defaults.object(forKey: key) as? Int, presets.contains(minutes) else {
            return nil
        }
        return minutes
    }

    // MARK: - Display

    public var phase: Phase { engine.phase }

    public var timeText: String { formatTime(engine.remaining(now: ticker.now)) }

    /// The image that shows the phase in the menu bar.
    public var phaseImage: PhaseImage {
        switch engine.phase {
        case .work: return .tomato
        case .break: return .coolTomato
        }
    }

    public var primaryActionTitle: String {
        switch engine.state {
        case .idle: return "Start"
        case .running: return "Pause"
        case .paused: return "Resume"
        }
    }

    /// The SF Symbol name for the primary action.
    public var primaryActionSymbol: String {
        switch engine.state {
        case .idle, .paused: return "play.fill"
        case .running: return "pause.fill"
        }
    }

    public var skipTitle: String {
        switch engine.phase {
        case .work: return "Skip to Break"
        case .break: return "Skip to Work"
        }
    }

    // MARK: - Actions

    // Each action first refreshes the engine. If the end date is in the past,
    // the phase finishes and the notification goes out before the action.

    public func primaryAction() {
        let date = clock()
        // If the phase finished in this refresh, the click does not start
        // the next phase.
        if refresh(at: date) { return }
        switch engine.state {
        case .idle: engine.start(now: date)
        case .running: engine.pause(now: date)
        case .paused: engine.resume(now: date)
        }
        updatePhaseEndNotification(at: date)
        refresh(at: date)
    }

    public func reset() {
        let date = clock()
        refresh(at: date)
        engine.reset()
        updatePhaseEndNotification(at: date)
        refresh(at: date)
    }

    public func skip() {
        let date = clock()
        refresh(at: date)
        engine.skip()
        updatePhaseEndNotification(at: date)
        refresh(at: date)
    }

    public func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Ticking

    /// Updates the engine and the display. It also starts or stops the tick loop.
    /// Returns true if the phase finished in this refresh.
    @discardableResult
    func refresh(at date: Date) -> Bool {
        var finished = false
        // The engine finishes a phase only in the running state.
        // Tick a copy. A change to the published engine on each tick
        // rebuilds the menu.
        if case .running(let endDate) = engine.state {
            var next = engine
            if case .phaseFinished(let phase) = next.tick(now: date) {
                engine = next
                phaseDidFinish(phase, endDate: endDate, at: date)
                finished = true
            }
        }
        ticker.now = date

        if case .running = engine.state {
            startTicking()
        } else {
            stopTicking()
        }
        return finished
    }

    private func startTicking() {
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Pomodoro timer runs"
            )
        }
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = self?.delayToNextSecond() else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                self.refresh(at: self.clock())
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    /// Returns the time until the shown value changes.
    /// The display rounds up, so the value changes on each full second
    /// of the remaining time.
    private func delayToNextSecond() -> TimeInterval {
        let remaining = engine.remaining(now: clock())
        let fraction = remaining - remaining.rounded(.down)
        // A small margin makes sure that the next tick is past the boundary.
        return (fraction > 0.005 ? fraction : 1) + 0.005
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh(at: self.clock())
            }
        }
    }

    // MARK: - Notifications

    /// Schedules the end notification while the timer runs. Else removes it.
    private func updatePhaseEndNotification(at date: Date) {
        if case .running = engine.state {
            notifications.schedule(
                for: engine.phase,
                after: engine.remaining(now: date),
                playSound: playSound
            )
        } else {
            notifications.cancel()
        }
    }

    /// The scheduled notification shows the end of the phase.
    ///
    /// If the end date is only a short time in the past, the controller does
    /// not remove the scheduled request. The request goes out at almost the
    /// same time, and a removal can stop it. If the end date is longer in
    /// the past, for example after sleep, the scheduled request possibly
    /// did not go out. Then the controller removes it and posts a new one.
    private func phaseDidFinish(_ phase: Phase, endDate: Date, at date: Date) {
        guard date.timeIntervalSince(endDate) > Self.lateNotificationLimit else { return }
        notifications.cancel()
        notifications.postNow(for: phase, playSound: playSound)
    }
}
