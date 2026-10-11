import XCTest

/// Checks that the App Store app has no Sparkle parts. App Review does not
/// let an App Store app update itself.
/// See https://developer.apple.com/app-store/review/guidelines/#2.4.5
final class AppStoreConfigTests: XCTestCase {
    private var app: BuiltApp!

    override func setUpWithError() throws {
        // Debug builds have a different name. See project.yml.
        app = try BuiltApp(named: "Timeato App Store")
    }

    func testHasNoSparkleFramework() {
        let framework = app.url.appendingPathComponent("Contents/Frameworks/Sparkle.framework")
        XCTAssertFalse(FileManager.default.fileExists(atPath: framework.path))
    }

    func testHasNoSparkleSettings() {
        let sparkleKeys = app.info.keys.filter { $0.hasPrefix("SU") }
        XCTAssertEqual(sparkleKeys, [])
    }

    func testIsSandboxedWithoutExceptions() throws {
        let entitlements = try app.entitlements()
        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertNil(entitlements["com.apple.security.network.client"])
        // Debug builds get Mach services for the test runner. The Sparkle
        // services must not be there.
        let key = "com.apple.security.temporary-exception.mach-lookup.global-name"
        let names = entitlements[key] as? [String] ?? []
        XCTAssertFalse(names.contains { $0.hasPrefix("com.skalnik.timeato") })
    }

    func testHasTheSameIdentityAsTheDirectApp() throws {
        let direct = try BuiltApp(named: "Timeato")
        for key in ["CFBundleIdentifier", "CFBundleDisplayName", "CFBundleShortVersionString", "CFBundleVersion", "LSUIElement"] {
            XCTAssertEqual(app.info[key] as? NSObject, direct.info[key] as? NSObject, key)
        }
    }
}
