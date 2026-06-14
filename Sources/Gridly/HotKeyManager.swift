import Carbon.HIToolbox
import Foundation

// File-scope storage accessible from the @convention(c) event handler
private var hotkeyCallbacks: [UInt32: () -> Void] = [:]
private var hotkeyRefs: [EventHotKeyRef] = []
private var nextID: UInt32 = 1

// Carbon event handler — must be a plain C function, so it lives at file scope.
private let carbonEventHandler: EventHandlerUPP = { _, event, _ -> OSStatus in
    var hkID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    hotkeyCallbacks[hkID.id]?()
    return noErr
}

// Four-char signature: 'WMGR'
private let kSignature: OSType = 0x574D4752

final class HotKeyManager {
    static let shared = HotKeyManager()

    private init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonEventHandler,
            1, &spec,
            nil, nil
        )
    }

    // MARK: - Registration

    /// Register a single hotkey.  `keyCode` is a Carbon kVK_* constant.
    /// `modifiers` uses Carbon modifier flags (controlKey | optionKey etc.).
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: kSignature, id: id)

        let status = RegisterEventHotKey(
            keyCode, modifiers, hkID,
            GetApplicationEventTarget(),
            0, &ref
        )

        if status == noErr, let ref {
            hotkeyRefs.append(ref)
            hotkeyCallbacks[id] = action
        }
    }

    // MARK: - Magnet default bindings

    func registerAll() {
        // ⌃⌥  (Control + Option)
        let co  = UInt32(controlKey | optionKey)
        // ⌃⌥⇧ (Control + Option + Shift)
        let cos = UInt32(controlKey | optionKey | shiftKey)

        // ── Halves (double-tap an arrow → throw to the monitor that way) ──────
        register(keyCode: UInt32(kVK_LeftArrow),  modifiers: co)  { [weak self] in self?.handleArrow(.left,  half: .leftHalf) }
        register(keyCode: UInt32(kVK_RightArrow), modifiers: co)  { [weak self] in self?.handleArrow(.right, half: .rightHalf) }
        register(keyCode: UInt32(kVK_UpArrow),    modifiers: co)  { [weak self] in self?.handleArrow(.up,    half: .topHalf) }
        register(keyCode: UInt32(kVK_DownArrow),  modifiers: co)  { [weak self] in self?.handleArrow(.down,  half: .bottomHalf) }

        // ── Fullscreen ───────────────────────────────────────────────────────
        register(keyCode: UInt32(kVK_Return),     modifiers: co)  { WindowMover.moveFrontmost(to: .maximize) }

        // ── Quarters ─────────────────────────────────────────────────────────
        //   U = top-left   I = top-right
        //   J = bot-left   K = bot-right
        register(keyCode: UInt32(kVK_ANSI_U), modifiers: co) { WindowMover.moveFrontmost(to: .topLeft) }
        register(keyCode: UInt32(kVK_ANSI_I), modifiers: co) { WindowMover.moveFrontmost(to: .topRight) }
        register(keyCode: UInt32(kVK_ANSI_J), modifiers: co) { WindowMover.moveFrontmost(to: .bottomLeft) }
        register(keyCode: UInt32(kVK_ANSI_K), modifiers: co) { WindowMover.moveFrontmost(to: .bottomRight) }

        // ── Thirds ───────────────────────────────────────────────────────────
        register(keyCode: UInt32(kVK_ANSI_D), modifiers: co) { WindowMover.moveFrontmost(to: .leftThird) }
        register(keyCode: UInt32(kVK_ANSI_F), modifiers: co) { WindowMover.moveFrontmost(to: .centerThird) }
        register(keyCode: UInt32(kVK_ANSI_G), modifiers: co) { WindowMover.moveFrontmost(to: .rightThird) }

        // ── Two-thirds ───────────────────────────────────────────────────────
        register(keyCode: UInt32(kVK_ANSI_E), modifiers: co) { WindowMover.moveFrontmost(to: .leftTwoThirds) }
        register(keyCode: UInt32(kVK_ANSI_T), modifiers: co) { WindowMover.moveFrontmost(to: .rightTwoThirds) }

        // ── 3×3 grid (numeric keypad + top number row) ───────────────────────
        //   7 8 9  (top)      digit → grid cell, laid out spatially on the keypad.
        //   4 5 6  (middle)   ⌃⌥<digit> snaps the frontmost window to that cell.
        //   1 2 3  (bottom)   ⌃⌥0 arranges *all* windows across the grid.
        let keypadCodes: [Int: Int] = [
            1: kVK_ANSI_Keypad1, 2: kVK_ANSI_Keypad2, 3: kVK_ANSI_Keypad3,
            4: kVK_ANSI_Keypad4, 5: kVK_ANSI_Keypad5, 6: kVK_ANSI_Keypad6,
            7: kVK_ANSI_Keypad7, 8: kVK_ANSI_Keypad8, 9: kVK_ANSI_Keypad9,
        ]
        let rowCodes: [Int: Int] = [
            1: kVK_ANSI_1, 2: kVK_ANSI_2, 3: kVK_ANSI_3,
            4: kVK_ANSI_4, 5: kVK_ANSI_5, 6: kVK_ANSI_6,
            7: kVK_ANSI_7, 8: kVK_ANSI_8, 9: kVK_ANSI_9,
        ]
        for (digit, code) in keypadCodes {
            register(keyCode: UInt32(code), modifiers: co) { WindowMover.moveFrontmost(to: .grid(digit)) }
        }
        for (digit, code) in rowCodes {
            register(keyCode: UInt32(code), modifiers: co) { WindowMover.moveFrontmost(to: .grid(digit)) }
        }
        register(keyCode: UInt32(kVK_ANSI_Keypad0), modifiers: co) { WindowMover.arrangeAllToGrid() }
        register(keyCode: UInt32(kVK_ANSI_0),       modifiers: co) { WindowMover.arrangeAllToGrid() }

        // ── Even tiling (⌃⌥⇧ + N) ────────────────────────────────────────────
        //   Splits the screen into N evenly-sized tiles and fills them with the
        //   N frontmost windows.  ⌃⌥⇧2 → halves, ⌃⌥⇧4 → 2×2, ⌃⌥⇧9 → 3×3, etc.
        for (digit, code) in rowCodes {
            register(keyCode: UInt32(code), modifiers: cos) { WindowMover.tileFrontmost(into: digit) }
        }
        for (digit, code) in keypadCodes {
            register(keyCode: UInt32(code), modifiers: cos) { WindowMover.tileFrontmost(into: digit) }
        }

        // ── Multi-display ────────────────────────────────────────────────────
        register(keyCode: UInt32(kVK_RightArrow), modifiers: cos) { WindowMover.moveFrontmost(to: .nextDisplay) }
        register(keyCode: UInt32(kVK_LeftArrow),  modifiers: cos) { WindowMover.moveFrontmost(to: .previousDisplay) }
    }

    // MARK: - Arrow double-tap

    /// Max gap between two taps of the same arrow to count as a double-tap.
    private let arrowDoubleTapInterval: TimeInterval = 0.30
    private var lastArrowDirection: ScreenDirection?
    private var lastArrowTime: TimeInterval = 0

    /// First ⌃⌥ + arrow tap snaps to `half`; a second tap of the same arrow
    /// within `arrowDoubleTapInterval` throws the window to the monitor in
    /// `direction` instead. Runs on the main thread (Carbon event loop), so the
    /// shared state needs no locking.
    private func handleArrow(_ direction: ScreenDirection, half: SnapPosition) {
        let now = ProcessInfo.processInfo.systemUptime
        let isDoubleTap = (direction == lastArrowDirection) &&
                          (now - lastArrowTime <= arrowDoubleTapInterval)

        if isDoubleTap {
            WindowMover.moveFocusedToAdjacentDisplay(direction: direction)
            lastArrowDirection = nil          // consume, so a third tap snaps again
        } else {
            WindowMover.moveFrontmost(to: half)
            lastArrowDirection = direction
            lastArrowTime = now
        }
    }
}
