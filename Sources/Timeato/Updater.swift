import Combine
import Sparkle
import SwiftUI
import TimeatoKit

/// Publishes the canCheckForUpdates value of the updater.
///
/// canCheckForUpdates supports KVO. This follows the SwiftUI example in the
/// Sparkle documentation.
/// See https://sparkle-project.org/documentation/programmatic-setup/
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }
}

/// The menu item that starts an update check.
///
/// The item is disabled while Sparkle cannot start a check.
struct CheckForUpdatesButton: View {
    @ObservedObject private var model: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.model = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button { updater.checkForUpdates() } label: {
            Label("Check for Updates…", systemImage: "arrow.down.circle")
        }
        .labelStyle(.titleAndIcon)
        .disabled(!model.canCheckForUpdates)
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
