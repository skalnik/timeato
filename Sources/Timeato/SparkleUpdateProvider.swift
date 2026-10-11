import Combine
import Sparkle
import TimeatoKit

/// Gives updates with Sparkle.
///
/// This object owns the Sparkle updater controller. It lives for the full
/// life of the app.
/// See https://sparkle-project.org/documentation/programmatic-setup/
@MainActor
final class SparkleUpdateProvider: UpdateProvider {
    private let controller: SPUStandardUpdaterController

    /// Sparkle keeps a weak reference to the user driver delegate. This
    /// property keeps the strong reference.
    private let userDriverDelegate: GentleUserDriverDelegate

    init() {
        // With the placeholder key, Sparkle cannot start. Then it shows an
        // alert at each launch. Thus the app does not start the updater
        // until the real key is in Info.plist. The menu item stays disabled.
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let startsUpdater = UpdaterConfig.hasPublicKey(publicKey)
        if !startsUpdater {
            NSLog("Updates are off. Put the Sparkle public key in Info.plist.")
        }

        let delegate = GentleUserDriverDelegate()
        userDriverDelegate = delegate
        controller = SPUStandardUpdaterController(
            startingUpdater: startsUpdater,
            updaterDelegate: nil,
            userDriverDelegate: delegate
        )
    }

    /// canCheckForUpdates supports KVO. This follows the SwiftUI example in
    /// the Sparkle documentation.
    var canCheckForUpdates: AnyPublisher<Bool, Never> {
        controller.updater.publisher(for: \.canCheckForUpdates).eraseToAnyPublisher()
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

/// Tells Sparkle that the app supports gentle update reminders.
///
/// The app has no Dock icon (LSUIElement). Sparkle recommends this
/// declaration for background apps. Then Sparkle does not show a scheduled
/// update alert in front of the frontmost app.
/// See https://sparkle-project.org/documentation/gentle-reminders/
///
/// The protocol is not isolated to the main actor. Thus this class is not
/// isolated either. It has no state.
final class GentleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
