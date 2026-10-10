import AppKit

/// Draws the phase glyph and the time text into one image.
///
/// The menu bar label of a `.menu` style MenuBarExtra becomes the button of
/// an NSStatusItem. The button shows only one image. Thus the glyph and the
/// time must be in the same image.
///
/// The menu bar label ignores font modifiers. Thus `.monospacedDigit()` has
/// no effect there, and the label width changes with the digits. A text box
/// of a fixed width keeps the menu bar item in the same position.
public enum TimeImageRenderer {
    /// NSFont is immutable. Thus the drawing handler can use it on any thread.
    nonisolated(unsafe) static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// The space between the glyph and the text.
    static let spacing: CGFloat = 4

    /// The size that fits "88:88" in the font, rounded up to full points.
    static let textSize: NSSize = {
        let text = ("88:88" as NSString).size(withAttributes: [.font: font])
        return NSSize(width: text.width.rounded(.up), height: text.height.rounded(.up))
    }()

    /// Returns the size of the image for the glyph.
    static func size(glyph: NSSize) -> NSSize {
        NSSize(
            width: glyph.width + spacing + textSize.width,
            height: max(glyph.height, textSize.height)
        )
    }

    /// Returns a template image with the glyph at the left and the text at
    /// the right. A template image follows the light or dark menu bar
    /// appearance. The drawing uses only the alpha of the glyph.
    public static func image(glyph: NSImage, text: String) -> NSImage {
        let glyphSize = glyph.size
        let image = NSImage(size: size(glyph: glyphSize), flipped: false) { rect in
            let glyphRect = NSRect(
                x: rect.minX,
                y: rect.midY - glyphSize.height / 2,
                width: glyphSize.width,
                height: glyphSize.height
            )
            glyph.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1)

            let box = NSRect(
                x: rect.maxX - textSize.width,
                y: rect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            let string = NSAttributedString(string: text, attributes: [.font: font])
            let stringSize = string.size()
            string.draw(at: NSPoint(
                x: box.midX - stringSize.width / 2,
                y: box.midY - stringSize.height / 2
            ))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = text
        return image
    }
}
