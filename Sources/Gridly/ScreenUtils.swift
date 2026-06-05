import AppKit

enum SnapPosition {
    // Halves
    case leftHalf, rightHalf, topHalf, bottomHalf
    // Fullscreen
    case maximize
    // Quarters
    case topLeft, topRight, bottomLeft, bottomRight
    // Thirds
    case leftThird, centerThird, rightThird
    // Two-thirds
    case leftTwoThirds, rightTwoThirds
    // 3×3 grid — `digit` is the numeric-keypad key (1…9), laid out spatially:
    //   7 8 9  (top)
    //   4 5 6  (middle)
    //   1 2 3  (bottom)
    case grid(Int)
    // Multi-display
    case nextDisplay, previousDisplay
}

enum ScreenUtils {
    // MARK: - Snap frame calculation

    /// Returns the target frame in AX coordinates (top-left origin) for the given
    /// snap position on the given screen.  Returns nil for display-move positions.
    static func axFrame(for position: SnapPosition, on screen: NSScreen) -> CGRect? {
        let f = screen.visibleFrame          // NSScreen coords (bottom-left origin)
        let mainH = NSScreen.screens[0].frame.height

        // Converts an NSRect (bottom-left origin) to AX / CGDisplay coordinates
        // (top-left origin of the primary screen).
        func ax(_ rect: NSRect) -> CGRect {
            CGRect(
                x: rect.minX,
                y: mainH - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        }

        switch position {
        case .leftHalf:
            return ax(NSRect(x: f.minX,             y: f.minY, width: f.width / 2,       height: f.height))
        case .rightHalf:
            return ax(NSRect(x: f.midX,             y: f.minY, width: f.width / 2,       height: f.height))
        case .topHalf:
            return ax(NSRect(x: f.minX,             y: f.midY, width: f.width,           height: f.height / 2))
        case .bottomHalf:
            return ax(NSRect(x: f.minX,             y: f.minY, width: f.width,           height: f.height / 2))
        case .maximize:
            return ax(f)

        case .topLeft:
            return ax(NSRect(x: f.minX,             y: f.midY, width: f.width / 2,       height: f.height / 2))
        case .topRight:
            return ax(NSRect(x: f.midX,             y: f.midY, width: f.width / 2,       height: f.height / 2))
        case .bottomLeft:
            return ax(NSRect(x: f.minX,             y: f.minY, width: f.width / 2,       height: f.height / 2))
        case .bottomRight:
            return ax(NSRect(x: f.midX,             y: f.minY, width: f.width / 2,       height: f.height / 2))

        case .leftThird:
            return ax(NSRect(x: f.minX,                         y: f.minY, width: f.width / 3,       height: f.height))
        case .centerThird:
            return ax(NSRect(x: f.minX + f.width / 3,           y: f.minY, width: f.width / 3,       height: f.height))
        case .rightThird:
            return ax(NSRect(x: f.minX + 2 * f.width / 3,       y: f.minY, width: f.width / 3,       height: f.height))

        case .leftTwoThirds:
            return ax(NSRect(x: f.minX,                         y: f.minY, width: 2 * f.width / 3,   height: f.height))
        case .rightTwoThirds:
            return ax(NSRect(x: f.minX + f.width / 3,           y: f.minY, width: 2 * f.width / 3,   height: f.height))

        case .grid(let digit):
            // Keypad digit → column (0…2 left→right) and row (0 bottom … 2 top).
            let col          = (digit - 1) % 3
            let rowFromBottom = (digit - 1) / 3
            let cw = f.width  / 3
            let ch = f.height / 3
            return ax(NSRect(x: f.minX + CGFloat(col) * cw,
                             y: f.minY + CGFloat(rowFromBottom) * ch,
                             width: cw, height: ch))

        case .nextDisplay, .previousDisplay:
            return nil
        }
    }

    // MARK: - Screen detection

    /// Returns the NSScreen that contains the window's top-left corner (AX coords).
    static func screen(containing window: AXUIElement) -> NSScreen {
        guard let pos = axPosition(of: window) else { return NSScreen.main! }

        let mainH = NSScreen.screens[0].frame.height

        for screen in NSScreen.screens {
            // Convert screen.frame (bottom-left origin) to AX/CG coords
            let axScreenFrame = CGRect(
                x: screen.frame.minX,
                y: mainH - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            if axScreenFrame.contains(pos) { return screen }
        }
        return NSScreen.main!
    }

    // MARK: - Adjacent screens

    static func nextScreen(after screen: NSScreen) -> NSScreen {
        let screens = NSScreen.screens
        guard let idx = screens.firstIndex(of: screen) else { return screen }
        return screens[(idx + 1) % screens.count]
    }

    static func previousScreen(before screen: NSScreen) -> NSScreen {
        let screens = NSScreen.screens
        guard let idx = screens.firstIndex(of: screen) else { return screen }
        return screens[(idx - 1 + screens.count) % screens.count]
    }

    // MARK: - Helpers

    private static func axPosition(of window: AXUIElement) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(ref as! AXValue, .cgPoint, &point)
        return point
    }
}
