import Foundation

/// The rules for the Sparkle settings in Info.plist.
public enum UpdaterConfig {
    /// The value of SUPublicEDKey in Info.plist before the developer puts
    /// the real key there.
    public static let placeholderPublicKey = "REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY"

    /// Returns true when the key is a real key. The updater starts only
    /// with a real key.
    public static func hasPublicKey(_ key: String?) -> Bool {
        guard let key, !key.isEmpty else { return false }
        return key != placeholderPublicKey
    }
}
