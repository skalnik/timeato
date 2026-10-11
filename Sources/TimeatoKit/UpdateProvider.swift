import Combine

/// Gives app updates to the menu.
///
/// The direct download uses Sparkle for updates. An App Store build gets its
/// updates from the App Store. It has no update provider, and the menu does
/// not show "Check for Updates…".
@MainActor
public protocol UpdateProvider: AnyObject {
    /// Sends true when the provider can start an update check now.
    var canCheckForUpdates: AnyPublisher<Bool, Never> { get }

    /// Starts an update check that shows its result to the user.
    func checkForUpdates()
}

/// Publishes the canCheckForUpdates value of an update provider for the
/// menu item.
@MainActor
public final class CheckForUpdatesViewModel: ObservableObject {
    @Published public private(set) var canCheckForUpdates = false

    private let provider: any UpdateProvider

    public init(provider: any UpdateProvider) {
        self.provider = provider
        provider.canCheckForUpdates.assign(to: &$canCheckForUpdates)
    }

    public func checkForUpdates() {
        provider.checkForUpdates()
    }
}
