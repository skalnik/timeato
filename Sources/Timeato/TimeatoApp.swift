import SwiftUI
import TimeatoCore
import TimeatoKit

@main
struct TimeatoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = TimerController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller, updateProvider: appDelegate.updateProvider)
        } label: {
            MenuBarLabel(controller: controller, ticker: controller.ticker)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The phase glyph and the time in the menu bar.
///
/// Only this view observes the ticker. Thus the change each second
/// updates the label, but does not rebuild the menu.
struct MenuBarLabel: View {
    @ObservedObject var controller: TimerController
    @ObservedObject var ticker: Ticker

    var body: some View {
        // The status item button shows only one image. Thus the glyph and
        // the time are in one image. The text box of a fixed width keeps
        // the item in one position.
        Image(nsImage: TimeImageRenderer.image(
            glyph: PhaseGlyph.image(for: controller.phaseImage),
            text: controller.timeText
        ))
    }
}

/// Maps a phase image to the glyph for the menu bar image.
@MainActor
enum PhaseGlyph {
    /// The size of the glyph in the menu bar, in points. The other menu bar
    /// icons are approximately 16 to 18 points high. The tomato assets have
    /// a small margin in their view box. Thus the app scales them up to this
    /// size. The assets keep their vector data, so they stay sharp.
    static let size = NSSize(width: 20, height: 20)

    /// The glyphs that the app loaded before.
    private static var cache: [PhaseImage: NSImage] = [:]

    static func image(for phaseImage: PhaseImage) -> NSImage {
        if let image = cache[phaseImage] {
            return image
        }
        let image = load(phaseImage)
        cache[phaseImage] = image
        return image
    }

    private static func load(_ phaseImage: PhaseImage) -> NSImage {
        switch phaseImage {
        case .tomato:
            return asset(named: "Tomato")
        case .coolTomato:
            return asset(named: "CoolTomato")
        }
    }

    /// Loads a template image from the asset catalog at the glyph size.
    private static func asset(named name: String) -> NSImage {
        let image = NSImage(named: name) ?? NSImage(size: size)
        if image.size != size {
            image.size = size
        }
        image.isTemplate = true
        return image
    }
}

/// The items in the menu bar menu.
struct MenuContent: View {
    @ObservedObject var controller: TimerController
    /// MenuContent does not observe the update provider. Only the update
    /// button observes it. When this value is nil, the menu has no update
    /// item.
    let updateProvider: (any UpdateProvider)?

    var body: some View {
        // In a menu, the label image shows in the image column of the item.
        // SwiftUI menus on macOS hide the icon of a Label by default.
        // Thus the title-and-icon style is necessary.
        Group {
            Button { controller.primaryAction() } label: {
                Label(controller.primaryActionTitle, systemImage: controller.primaryActionSymbol)
            }
            Button { controller.reset() } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            Button { controller.skip() } label: {
                Label(controller.skipTitle, systemImage: "forward.end.fill")
            }
        }
        .labelStyle(.titleAndIcon)

        Divider()

        Menu("Durations") {
            Section("Work") {
                Picker("Work", selection: $controller.workMinutes) {
                    ForEach(TimerController.workPresets, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Break") {
                Picker("Break", selection: $controller.breakMinutes) {
                    ForEach(TimerController.breakPresets, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }

        Toggle("Play Sound When Done", isOn: $controller.playSound)

        Divider()

        if let updateProvider {
            CheckForUpdatesButton(provider: updateProvider)
        }

        Button("Quit Timeato") { controller.quit() }
            .keyboardShortcut("q")
    }
}
