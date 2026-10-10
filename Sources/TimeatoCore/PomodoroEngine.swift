import Foundation

/// A phase of the pomodoro cycle.
public enum Phase: String, Sendable, CaseIterable {
    case work
    case `break`

    /// The phase that comes after this phase.
    public var next: Phase {
        switch self {
        case .work: return .break
        case .break: return .work
        }
    }
}

/// The state of the timer.
public enum TimerState: Equatable, Sendable {
    /// The timer does not run. The current phase shows its full duration.
    case idle
    /// The timer runs. The phase ends at the end date.
    case running(endDate: Date)
    /// The timer is stopped. The value is the time that remains in the phase.
    case paused(remaining: TimeInterval)
}

/// An event that the engine sends out.
public enum Event: Equatable, Sendable {
    /// The phase in the value is complete.
    case phaseFinished(Phase)
}

/// The duration of each phase, in seconds.
public struct Durations: Equatable, Sendable {
    public var work: TimeInterval
    public var breakTime: TimeInterval

    public static let `default` = Durations(work: 25 * 60, breakTime: 5 * 60)

    public init(work: TimeInterval, breakTime: TimeInterval) {
        self.work = work
        self.breakTime = breakTime
    }

    /// Returns the duration for a phase.
    public func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .work: return work
        case .break: return breakTime
        }
    }
}

/// The pomodoro state machine.
///
/// The engine does not read the clock. Each call gets the current date
/// from the caller. Thus the engine is deterministic and easy to test.
public struct PomodoroEngine: Equatable, Sendable {
    public private(set) var phase: Phase
    public private(set) var state: TimerState

    /// The phase durations. A change applies to the next run only.
    /// A running or paused phase keeps its end date or remaining time.
    public var durations: Durations

    public init(durations: Durations = .default, phase: Phase = .work) {
        self.durations = durations
        self.phase = phase
        self.state = .idle
    }

    /// Starts the current phase. This has an effect only in the idle state.
    public mutating func start(now: Date) {
        guard case .idle = state else { return }
        state = .running(endDate: now.addingTimeInterval(durations.duration(for: phase)))
    }

    /// Pauses the timer. This has an effect only in the running state.
    public mutating func pause(now: Date) {
        guard case .running(let endDate) = state else { return }
        state = .paused(remaining: max(0, endDate.timeIntervalSince(now)))
    }

    /// Resumes the timer. This has an effect only in the paused state.
    public mutating func resume(now: Date) {
        guard case .paused(let remaining) = state else { return }
        state = .running(endDate: now.addingTimeInterval(remaining))
    }

    /// Stops the timer and loads the full duration of the current phase.
    public mutating func reset() {
        state = .idle
    }

    /// Stops the timer and loads the other phase.
    public mutating func skip() {
        phase = phase.next
        state = .idle
    }

    /// Updates the engine for the current date.
    ///
    /// If the end date is in the past, the engine loads the next phase,
    /// goes to the idle state, and returns the finish event.
    /// The engine returns the event one time only for each run.
    public mutating func tick(now: Date) -> Event? {
        guard case .running(let endDate) = state, now >= endDate else { return nil }
        let finished = phase
        phase = phase.next
        state = .idle
        return .phaseFinished(finished)
    }

    /// Returns the time that remains in the current phase.
    public func remaining(now: Date) -> TimeInterval {
        switch state {
        case .idle:
            return durations.duration(for: phase)
        case .running(let endDate):
            return max(0, endDate.timeIntervalSince(now))
        case .paused(let remaining):
            return remaining
        }
    }
}

/// Formats a time interval as `MM:SS`.
///
/// The function rounds up to the next full second. Thus the display shows
/// `00:01` until the phase is complete, and `25:00` at the start.
/// Negative values show as `00:00`.
public func formatTime(_ interval: TimeInterval) -> String {
    let total = Int(max(0, interval).rounded(.up))
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
