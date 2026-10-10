import XCTest
@testable import TimeatoKit

final class TimeImageRendererTests: XCTestCase {
    /// An empty glyph of the menu bar glyph size.
    private let glyph = NSImage(size: NSSize(width: 20, height: 20))

    func testImageSizeIsTheSameForAllDigits() {
        let narrow = TimeImageRenderer.image(glyph: glyph, text: "11:11")
        let wide = TimeImageRenderer.image(glyph: glyph, text: "25:00")
        XCTAssertEqual(narrow.size.width, wide.size.width)
        XCTAssertEqual(narrow.size, TimeImageRenderer.size(glyph: glyph.size))
    }

    func testImageSizeContainsGlyphSpacingAndText() {
        let image = TimeImageRenderer.image(glyph: glyph, text: "25:00")
        XCTAssertEqual(
            image.size.width,
            20 + TimeImageRenderer.spacing + TimeImageRenderer.textSize.width
        )
        XCTAssertEqual(image.size.height, max(20, TimeImageRenderer.textSize.height))
    }

    func testImageHeightIsTheGlyphHeight() {
        // The text is lower than the glyph. Thus the glyph sets the height,
        // and the text is centered on the glyph.
        XCTAssertLessThanOrEqual(TimeImageRenderer.textSize.height, 20)
        XCTAssertEqual(TimeImageRenderer.image(glyph: glyph, text: "25:00").size.height, 20)
    }

    func testImageIsTemplate() {
        XCTAssertTrue(TimeImageRenderer.image(glyph: glyph, text: "25:00").isTemplate)
    }

    func testTextSizeFitsTheWidestText() {
        let text = ("88:88" as NSString).size(withAttributes: [.font: TimeImageRenderer.font])
        XCTAssertGreaterThanOrEqual(TimeImageRenderer.textSize.width, text.width)
        XCTAssertEqual(TimeImageRenderer.textSize.width, TimeImageRenderer.textSize.width.rounded(.up))
    }
}
