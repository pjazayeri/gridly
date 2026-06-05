import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestAccessibilityIfNeeded()
        HotKeyManager.shared.registerAll()
    }

    // MARK: - Menu bar

    /// Right-click menu — built once, shown on demand so left-click stays free
    /// to open Preferences directly.
    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Gridly", action: #selector(quit), keyEquivalent: "q")
        )
        return menu
    }()

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "Window Manager"
            )
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// Left-click opens Preferences; right-click shows the menu.
    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent, let button = statusItem?.button else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem?.menu = contextMenu
            button.performClick(nil)          // pops the menu
            statusItem?.menu = nil            // detach so left-click stays an action
        } else {
            openPreferences()
        }
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
