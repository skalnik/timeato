import TimeatoKit

/// The App Store gives the updates. App Review does not let an App Store
/// app update itself. Thus this build has no update provider.
/// See https://developer.apple.com/app-store/review/guidelines/#2.4.5
@MainActor
func makeUpdateProvider() -> (any UpdateProvider)? {
    nil
}
