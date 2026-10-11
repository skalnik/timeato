import XCTest

/// An app that Xcode built next to the test bundle.
///
/// The tests do not run in an app. Xcode puts the apps and the test bundle
/// in the same products folder. Thus the tests read the apps from there.
struct BuiltApp {
    let url: URL
    let info: [String: Any]

    init(named name: String) throws {
        let products = Bundle(for: BundleLocator.self).bundleURL.deletingLastPathComponent()
        url = products.appendingPathComponent("\(name).app")
        let bundle = try XCTUnwrap(Bundle(url: url), "Xcode did not build \(name).app")
        info = try XCTUnwrap(bundle.infoDictionary)
    }

    /// Reads the entitlements from the code signature of the app.
    /// See https://developer.apple.com/documentation/security/seccodecopysigninginformation(_:_:_:)
    func entitlements() throws -> [String: Any] {
        var code: SecStaticCode?
        XCTAssertEqual(SecStaticCodeCreateWithPath(url as CFURL, [], &code), errSecSuccess)
        var signing: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        XCTAssertEqual(SecCodeCopySigningInformation(try XCTUnwrap(code), flags, &signing), errSecSuccess)
        let dictionary = try XCTUnwrap(signing as? [String: Any])
        return try XCTUnwrap(dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
    }
}

/// Bundle(for:) needs a class in the test bundle.
private final class BundleLocator {}
