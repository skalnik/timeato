import AppKit
import TimeatoKit

/// Owns the objects that live for the full life of the app.
///
/// File Cloud keeps its Sparkle updater controller in its app delegate.
/// Timeato does the same.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Each app target has its own makeUpdateProvider function. The direct
    /// target has it in Sources/Direct. The App Store target has it in
    /// Sources/AppStore. When this value is nil, the app does not check for
    /// updates itself.
    let updateProvider: (any UpdateProvider)? = makeUpdateProvider()
}
