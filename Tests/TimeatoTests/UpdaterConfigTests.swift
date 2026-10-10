import XCTest
import TimeatoKit

/// Checks the Sparkle settings in the Info.plist of the app.
///
/// The tests do not run in the app. Xcode puts the app and the test bundle
/// in the same products folder. Thus the tests read the Info.plist of the
/// app from there.
final class UpdaterConfigTests: XCTestCase {
    private var info: [String: Any] = [:]

    override func setUpWithError() throws {
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let app = try XCTUnwrap(Bundle(url: products.appendingPathComponent("Timeato.app")))
        info = try XCTUnwrap(app.infoDictionary)
    }

    func testFeedIsHTTPS() throws {
        let feed = try XCTUnwrap(info["SUFeedURL"] as? String)
        XCTAssertEqual(URL(string: feed)?.scheme, "https")
    }

    func testPublicKeyIsEd25519OrPlaceholder() throws {
        let key = try XCTUnwrap(info["SUPublicEDKey"] as? String)
        // The placeholder stays until the developer makes the keys.
        if key == UpdaterConfig.placeholderPublicKey {
            return
        }
        XCTAssertEqual(Data(base64Encoded: key)?.count, 32)
    }

    func testBuildNumberIsAnInteger() throws {
        let build = try XCTUnwrap(info["CFBundleVersion"] as? String)
        XCTAssertNotNil(Int(build), "Sparkle compares the build number")
    }

    func testVersionIsTheDate() throws {
        let version = try XCTUnwrap(info["CFBundleShortVersionString"] as? String)
        XCTAssertNotNil(version.range(of: #"^\d{4}\.\d{2}\.\d{2}$"#, options: .regularExpression))
    }

    func testAppIsMenuBarOnly() {
        XCTAssertEqual(info["LSUIElement"] as? Bool, true)
    }

    func testPlaceholderKeyDoesNotStartTheUpdater() {
        XCTAssertFalse(UpdaterConfig.hasPublicKey(UpdaterConfig.placeholderPublicKey))
        XCTAssertFalse(UpdaterConfig.hasPublicKey(nil))
        XCTAssertFalse(UpdaterConfig.hasPublicKey(""))
        XCTAssertTrue(UpdaterConfig.hasPublicKey("GeU/AHS2hVvRFgJ8ypV1ihSZE54RruVgQKXevmwa2As="))
    }
}
