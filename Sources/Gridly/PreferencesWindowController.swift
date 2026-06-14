import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        // Give the window a concrete size up front. Sizing it from the SwiftUI
        // content (`.preferredContentSize`) is fragile: a ScrollView reports no
        // intrinsic height, so the window can collapse, and centring a still-
        // zero-sized window pushes its title bar off-screen once it grows.
        let hosting = NSHostingView(rootView: PreferencesView())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        window.title = "Gridly"
        window.contentView = hosting
        window.isReleasedWhenClosed = false   // keep alive for next open

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        guard let window else { return }
        window.center()                       // centre now that it has a real size

        // .accessory apps aren't "active", so a plain makeKeyAndOrderFront can
        // open the window *behind* the frontmost app. orderFrontRegardless
        // forces it above other apps' windows even while we're inactive.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
