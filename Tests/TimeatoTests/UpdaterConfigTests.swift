import XCTest
import TimeatoKit

/// Checks the Sparkle settings in the Info.plist of the app, and the
/// sandbox entitlements in its code signature.
///
/// The tests do not run in the app. Xcode puts the app and the test bundle
/// in the same products folder. Thus the tests read the Info.plist of the
/// app from there.
final class UpdaterConfigTests: XCTestCase {
    private var appURL: URL!
    private var info: [String: Any] = [:]

    override func setUpWithError() throws {
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        appURL = products.appendingPathComponent("Timeato.app")
        let app = try XCTUnwrap(Bundle(url: appURL))
        info = try XCTUnwrap(app.infoDictionary)
    }

    /// Reads the entitlements from the code signature of the app.
    /// See https://developer.apple.com/documentation/security/seccodecopysigninginformation(_:_:_:)
    private func entitlements() throws -> [String: Any] {
        var code: SecStaticCode?
        XCTAssertEqual(SecStaticCodeCreateWithPath(appURL as CFURL, [], &code), errSecSuccess)
        var signing: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        XCTAssertEqual(SecCodeCopySigningInformation(try XCTUnwrap(code), flags, &signing), errSecSuccess)
        let dictionary = try XCTUnwrap(signing as? [String: Any])
        return try XCTUnwrap(dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
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
        let entitlements = try entitlements()
        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertNil(entitlements["com.apple.security.network.client"])
    }

    func testSparkleMachServicesUseTheBundleIdentifier() throws {
        let key = "com.apple.security.temporary-exception.mach-lookup.global-name"
        let names = try XCTUnwrap(entitlements()[key] as? [String])
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
