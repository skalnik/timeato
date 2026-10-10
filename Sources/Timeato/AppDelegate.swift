import AppKit
import Sparkle
import TimeatoKit

/// Owns the objects that live for the full life of the app.
///
/// File Cloud keeps its Sparkle updater controller in its app delegate.
/// Timeato does the same.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController: SPUStandardUpdaterController

    /// Sparkle keeps a weak reference to the user driver delegate. This
    /// property keeps the strong reference.
    private let userDriverDelegate: GentleUserDriverDelegate

    override init() {
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
        updaterController = SPUStandardUpdaterController(
            startingUpdater: startsUpdater,
            updaterDelegate: nil,
            userDriverDelegate: delegate
        )
        super.init()
    }
}
