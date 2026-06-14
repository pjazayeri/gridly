import AppKit

enum WindowMover {
    // MARK: - Public

    static func moveFrontmost(to position: SnapPosition) {
        guard let window = focusedWindow() else { return }

        switch position {
        case .nextDisplay:
            moveToAdjacentDisplay(window, forward: true)
        case .previousDisplay:
            moveToAdjacentDisplay(window, forward: false)
        default:
            let screen = ScreenUtils.screen(containing: window)
            if let frame = ScreenUtils.axFrame(for: position, on: screen) {
                setFrame(of: window, to: frame)
            }
        }
    }

    /// Distributes every standard window across the 3×3 grid, cycling through
    /// cells 1…9 so each window lands on a grid spot (cells repeat past 9 windows).
    /// Each window is placed on the grid of the screen it currently occupies.
    static func arrangeAllToGrid() {
        var index = 0
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var winRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &winRef) == .success,
                  let windows = winRef as? [AXUIElement] else { continue }

            for window in windows where isArrangeable(window) {
                let screen = ScreenUtils.screen(containing: window)
                let digit  = (index % 9) + 1
                if let frame = ScreenUtils.axFrame(for: .grid(digit), on: screen) {
                    setFrame(of: window, to: frame)
                }
                index += 1
            }
        }
    }

    /// Moves the focused window to the display physically in `direction`
    /// (above / below / left / right), preserving its relative size and
    /// position. No-op if there is no display that way (e.g. a single screen).
    static func moveFocusedToAdjacentDisplay(direction: ScreenDirection) {
        guard let window = focusedWindow() else { return }
        let current = ScreenUtils.screen(containing: window)
        guard let target = ScreenUtils.adjacentScreen(of: current, in: direction) else { return }
        reposition(window, from: current, to: target)
    }

    /// Tiles the `count` frontmost standard windows into an even grid that
    /// fills the screen holding the focused window.  If fewer than `count`
    /// windows exist, the grid shrinks to the number actually available so the
    /// split never leaves empty cells.
    static func tileFrontmost(into count: Int) {
        guard count >= 1 else { return }

        let windows = arrangeableWindowsFrontmostFirst()
        guard let anchor = windows.first else { return }

        let n = min(count, windows.count)
        let screen = ScreenUtils.screen(containing: anchor)
        let frames = ScreenUtils.tileFrames(count: n, on: screen)

        for (window, frame) in zip(windows, frames) {
            setFrame(of: window, to: frame)
        }
    }

    // MARK: - Private

    /// Every arrangeable standard window across regular apps, with the frontmost
    /// app's windows first so tiling starts from what the user is looking at.
    private static func arrangeableWindowsFrontmostFirst() -> [AXUIElement] {
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { a, _ in a.processIdentifier == frontPID }

        var result: [AXUIElement] = []
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var winRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &winRef) == .success,
                  let windows = winRef as? [AXUIElement] else { continue }
            result.append(contentsOf: windows.filter { isArrangeable($0) })
        }
        return result
    }

    /// True for ordinary, non-minimized application windows (skips panels,
    /// sheets, and minimized windows so the arrange pass leaves them alone).
    private static func isArrangeable(_ window: AXUIElement) -> Bool {
        var subroleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef) == .success,
              (subroleRef as? String) == (kAXStandardWindowSubrole as String)
        else { return false }

        var minRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRef) == .success,
           (minRef as? Bool) == true {
            return false
        }
        return true
    }

    private static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return (ref as! AXUIElement)
    }

    private static func setFrame(of window: AXUIElement, to frame: CGRect) {
        var origin = frame.origin
        var size   = frame.size

        if let posValue  = AXValueCreate(.cgPoint, &origin) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize,  &size) {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private static func moveToAdjacentDisplay(_ window: AXUIElement, forward: Bool) {
        let current = ScreenUtils.screen(containing: window)
        let target  = forward
            ? ScreenUtils.nextScreen(after: current)
            : ScreenUtils.previousScreen(before: current)
        reposition(window, from: current, to: target)
    }

    /// Moves `window` from `src` to `dst`, keeping its size and its position
    /// relative to the screen's visible frame (a left-half window stays a
    /// left-half window on the destination display).
    private static func reposition(_ window: AXUIElement, from src: NSScreen, to dst: NSScreen) {
        guard src != dst else { return }

        // Read current position and size
        var posRef:  CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)  == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute    as CFString, &sizeRef) == .success,
              let posRef, let sizeRef
        else { return }

        var axPos  = CGPoint.zero
        var axSize = CGSize.zero
        AXValueGetValue(posRef  as! AXValue, .cgPoint, &axPos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize,  &axSize)

        let mainH = NSScreen.screens[0].frame.height

        // Relative position of the window within the current screen's visible frame
        // (working in NSScreen bottom-left coords for clarity)
        let srcF = src.visibleFrame
        let dstF = dst.visibleFrame

        let nsWindowY = mainH - axPos.y - axSize.height   // convert AX → NS y
        let relX = (axPos.x   - srcF.minX) / srcF.width
        let relY = (nsWindowY - srcF.minY) / srcF.height

        let newNsX = dstF.minX + relX * dstF.width
        let newNsY = dstF.minY + relY * dstF.height
        let newAxY = mainH - newNsY - axSize.height

        var newOrigin = CGPoint(x: newNsX, y: newAxY)
        if let posValue = AXValueCreate(.cgPoint, &newOrigin) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
    }
}
