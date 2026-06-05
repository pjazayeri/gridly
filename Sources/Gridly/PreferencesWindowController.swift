import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let hosting = NSHostingView(rootView: PreferencesView())
        hosting.sizingOptions = .preferredContentSize

        let window = NSWindow(
            contentRect: .zero,
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        window.title = "Gridly"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false   // keep alive for next open

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
