import XCTest
import TimeatoKit

/// Checks the Sparkle settings in the Info.plist of the direct app, and the
/// sandbox entitlements in its code signature.
final class UpdaterConfigTests: XCTestCase {
    private var app: BuiltApp!
    private var info: [String: Any] { app.info }

    override func setUpWithError() throws {
        app = try BuiltApp(named: "Timeato")
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

    func testSparkleUsesItsSandboxServices() {
        XCTAssertEqual(info["SUEnableInstallerLauncherService"] as? Bool, true)
        // The downloader service does the network access. Thus the app does
        // not need the network client entitlement.
        XCTAssertEqual(info["SUEnableDownloaderService"] as? Bool, true)
    }

    func testAppIsSandboxed() throws {
        let entitlements = try app.entitlements()
        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertNil(entitlements["com.apple.security.network.client"])
    }

    func testSparkleMachServicesUseTheBundleIdentifier() throws {
        let key = "com.apple.security.temporary-exception.mach-lookup.global-name"
        let names = try XCTUnwrap(app.entitlements()[key] as? [String])
        // Debug builds also get Mach services for the test runner. The
        // archive export removes them.
        XCTAssertTrue(Set(names).isSuperset(of: ["com.skalnik.timeato-spks", "com.skalnik.timeato-spki"]))
    }

    func testPlaceholderKeyDoesNotStartTheUpdater() {
        XCTAssertFalse(UpdaterConfig.hasPublicKey(UpdaterConfig.placeholderPublicKey))
        XCTAssertFalse(UpdaterConfig.hasPublicKey(nil))
        XCTAssertFalse(UpdaterConfig.hasPublicKey(""))
        XCTAssertTrue(UpdaterConfig.hasPublicKey("GeU/AHS2hVvRFgJ8ypV1ihSZE54RruVgQKXevmwa2As="))
    }
}
