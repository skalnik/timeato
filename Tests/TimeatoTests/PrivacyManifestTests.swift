import XCTest

/// Checks the privacy manifest in both apps. The App Store rejects an
/// upload that uses UserDefaults without a declared reason.
/// See https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
final class PrivacyManifestTests: XCTestCase {
    private func manifest(in name: String) throws -> [String: Any] {
        let app = try BuiltApp(named: name)
        let url = app.url.appendingPathComponent("Contents/Resources/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func checkManifest(in name: String) throws {
        let manifest = try manifest(in: name)
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false, name)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0, name)

        let types = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]], name)
        let defaults = types.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        XCTAssertEqual(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"], name)
    }

    func testDirectAppHasTheManifest() throws {
        try checkManifest(in: "Timeato")
    }

    func testAppStoreAppHasTheManifest() throws {
        // Debug builds have a different name. See project.yml.
        try checkManifest(in: "Timeato App Store")
    }
}
