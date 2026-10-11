import SwiftUI
import TimeatoKit

/// The menu item that starts an update check.
///
/// The item is disabled while the update provider cannot start a check.
struct CheckForUpdatesButton: View {
    @StateObject private var model: CheckForUpdatesViewModel

    init(provider: any UpdateProvider) {
        _model = StateObject(wrappedValue: CheckForUpdatesViewModel(provider: provider))
    }

    var body: some View {
        Button { model.checkForUpdates() } label: {
            Label("Check for Updates…", systemImage: "arrow.down.circle")
        }
        .labelStyle(.titleAndIcon)
        .disabled(!model.canCheckForUpdates)
    }
}
