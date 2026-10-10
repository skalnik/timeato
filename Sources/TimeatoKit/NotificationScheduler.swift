import os
import TimeatoCore
import UserNotifications

/// Shows the notification for the end of a phase.
///
/// The controller uses this protocol. Tests give the controller a fake.
@MainActor
protocol NotificationScheduling: AnyObject {
    /// Asks the user for permission to show notifications.
    func requestAuthorization()

    /// Schedules the notification for the end of the phase.
    /// The new request replaces a request that is scheduled.
    func schedule(for phase: Phase, after interval: TimeInterval, playSound: Bool)

    /// Removes the scheduled request, if it did not go out yet.
    func cancel()

    /// Shows the notification for the end of the phase immediately.
    func postNow(for phase: Phase, playSound: Bool)
}

/// Schedules the phase end notification with the system.
///
/// The system shows a scheduled notification at the correct time, also if
/// App Nap slows down the app. See
/// https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger
@MainActor
final class NotificationScheduler: NotificationScheduling {
    /// All scheduled requests use this identifier. Thus there is never
    /// more than one scheduled request.
    static let phaseEndIdentifier = "phase-end"

    /// The logger is `nonisolated` because callbacks off the main actor use it.
    /// `Logger` is `Sendable`, so this is safe.
    nonisolated private static let logger = Logger(subsystem: "com.skalnik.timeato", category: "notifications")

    private let center: UNUserNotificationCenter
    private let delegate = NotificationDelegate()

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        center.delegate = delegate
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NotificationScheduler.logger.error("Notification authorization failed: \(error)")
            }
        }
    }

    func schedule(for phase: Phase, after interval: TimeInterval, playSound: Bool) {
        // The trigger needs an interval that is more than zero.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(interval, 1), repeats: false)
        add(UNNotificationRequest(
            identifier: Self.phaseEndIdentifier,
            content: Self.content(for: phase, playSound: playSound),
            trigger: trigger
        ))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.phaseEndIdentifier])
    }

    func postNow(for phase: Phase, playSound: Bool) {
        add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: Self.content(for: phase, playSound: playSound),
            trigger: nil
        ))
    }

    private func add(_ request: UNNotificationRequest) {
        center.add(request) { error in
            if let error {
                NotificationScheduler.logger.error("Cannot add the notification: \(error)")
            }
        }
    }

    /// Returns the text and the sound for the end of the phase.
    static func content(for finished: Phase, playSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch finished {
        case .work:
            content.title = "Take a break"
            content.body = "All work and no play makes for a mealy tomato"
        case .break:
            content.title = "Back to work"
            content.body = "Get back to it lest you rot!"
        }
        if playSound {
            content.sound = .default
        }
        return content
    }
}

/// Shows the notification banner also when the app is in the foreground.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
