import SwiftUI
import ServiceManagement

// MARK: - Data model

struct ShortcutEntry: Identifiable {
    let id   = UUID()
    let action:   String
    let shortcut: String
    /// Where the window lands, as a fraction of the screen (top-left origin).
    /// `nil` for entries shown with a `symbol` instead (tiling, displays, etc.).
    var region:   CGRect? = nil
    /// SF Symbol drawn in the thumbnail when there is no single `region`.
    var symbol:   String? = nil
}

struct ShortcutGroup: Identifiable {
    let id      = UUID()
    let title:   String
    let entries: [ShortcutEntry]
    var note:    String? = nil
}

/// Fractional rect helper (top-left origin, values 0…1).
private func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
}
private let t = 1.0 / 3.0

private let shortcutGroups: [ShortcutGroup] = [
    ShortcutGroup(title: "Halves", entries: [
        ShortcutEntry(action: "Left Half",    shortcut: "⌃⌥←", region: r(0,   0, 0.5, 1)),
        ShortcutEntry(action: "Right Half",   shortcut: "⌃⌥→", region: r(0.5, 0, 0.5, 1)),
        ShortcutEntry(action: "Top Half",     shortcut: "⌃⌥↑", region: r(0,   0, 1, 0.5)),
        ShortcutEntry(action: "Bottom Half",  shortcut: "⌃⌥↓", region: r(0, 0.5, 1, 0.5)),
    ]),
    ShortcutGroup(title: "Fullscreen", entries: [
        ShortcutEntry(action: "Maximize",     shortcut: "⌃⌥↩", region: r(0, 0, 1, 1)),
    ]),
    ShortcutGroup(title: "Quarters", entries: [
        ShortcutEntry(action: "Top Left",     shortcut: "⌃⌥U", region: r(0,   0,   0.5, 0.5)),
        ShortcutEntry(action: "Top Right",    shortcut: "⌃⌥I", region: r(0.5, 0,   0.5, 0.5)),
        ShortcutEntry(action: "Bottom Left",  shortcut: "⌃⌥J", region: r(0,   0.5, 0.5, 0.5)),
        ShortcutEntry(action: "Bottom Right", shortcut: "⌃⌥K", region: r(0.5, 0.5, 0.5, 0.5)),
    ]),
    ShortcutGroup(title: "Thirds", entries: [
        ShortcutEntry(action: "Left Third",       shortcut: "⌃⌥D", region: r(0,   0, t, 1)),
        ShortcutEntry(action: "Center Third",     shortcut: "⌃⌥F", region: r(t,   0, t, 1)),
        ShortcutEntry(action: "Right Third",      shortcut: "⌃⌥G", region: r(2*t, 0, t, 1)),
        ShortcutEntry(action: "Left Two-Thirds",  shortcut: "⌃⌥E", region: r(0,   0, 2*t, 1)),
        ShortcutEntry(action: "Right Two-Thirds", shortcut: "⌃⌥T", region: r(t,   0, 2*t, 1)),
    ]),
    ShortcutGroup(title: "3×3 Grid", entries: [
        ShortcutEntry(action: "Top Left",      shortcut: "⌃⌥7", region: r(0,   0,   t, t)),
        ShortcutEntry(action: "Top Center",    shortcut: "⌃⌥8", region: r(t,   0,   t, t)),
        ShortcutEntry(action: "Top Right",     shortcut: "⌃⌥9", region: r(2*t, 0,   t, t)),
        ShortcutEntry(action: "Middle Left",   shortcut: "⌃⌥4", region: r(0,   t,   t, t)),
        ShortcutEntry(action: "Middle Center", shortcut: "⌃⌥5", region: r(t,   t,   t, t)),
        ShortcutEntry(action: "Middle Right",  shortcut: "⌃⌥6", region: r(2*t, t,   t, t)),
        ShortcutEntry(action: "Bottom Left",   shortcut: "⌃⌥1", region: r(0,   2*t, t, t)),
        ShortcutEntry(action: "Bottom Center", shortcut: "⌃⌥2", region: r(t,   2*t, t, t)),
        ShortcutEntry(action: "Bottom Right",  shortcut: "⌃⌥3", region: r(2*t, 2*t, t, t)),
        ShortcutEntry(action: "Arrange All Windows", shortcut: "⌃⌥0", symbol: "square.grid.3x3.fill"),
    ], note: "Numbers match a numeric keypad's layout."),
    ShortcutGroup(title: "Even Tiling", entries: [
        ShortcutEntry(action: "Split into 2 (halves)", shortcut: "⌃⌥⇧2", symbol: "rectangle.split.2x1"),
        ShortcutEntry(action: "Split into 3",          shortcut: "⌃⌥⇧3", symbol: "rectangle.split.3x1"),
        ShortcutEntry(action: "Split into 4 (2×2)",    shortcut: "⌃⌥⇧4", symbol: "square.grid.2x2"),
        ShortcutEntry(action: "Split into N (1–9)",    shortcut: "⌃⌥⇧#", symbol: "square.grid.3x3"),
    ], note: "Tiles your N frontmost windows to fill the screen evenly."),
    ShortcutGroup(title: "Displays", entries: [
        ShortcutEntry(action: "Next Display",     shortcut: "⌃⌥⇧→", symbol: "arrow.right.square"),
        ShortcutEntry(action: "Previous Display", shortcut: "⌃⌥⇧←", symbol: "arrow.left.square"),
    ], note: "Requires a second display connected."),
]

// MARK: - Root view

struct PreferencesView: View {
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    howToUse
                    ForEach(shortcutGroups) { GroupSection(group: $0) }
                }
                .padding(20)
            }
            .frame(maxHeight: 460)
            Divider()
            loginToggle
        }
        .frame(width: 380)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "rectangle.3.group")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Gridly")
                    .font(.title2.weight(.semibold))
                Text("Keyboard window snapping for macOS")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: How to use

    private var howToUse: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to use")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Step(number: 1, text: "Gridly runs quietly in your menu bar — no window of its own.")
                Step(number: 2, text: "Click any window to focus it, then press a shortcut below to snap it into place.")
                Step(number: 3, text: "Hold the modifiers (⌃ Control, ⌥ Option, sometimes ⇧ Shift) and tap the key.")
            }
            Label("Needs Accessibility permission — System Settings ▸ Privacy & Security ▸ Accessibility.",
                  systemImage: "lock.shield")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Launch at login

    private var loginToggle: some View {
        Toggle(isOn: $launchAtLogin) {
            Text("Launch at Login")
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled { try SMAppService.mainApp.register() }
                else       { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = !enabled   // revert if it failed
            }
        }
    }
}

// MARK: - Sub-views

private struct Step: View {
    let number: Int
    let text:   String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GroupSection: View {
    let group: ShortcutGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(group.entries.enumerated()), id: \.element.id) { idx, entry in
                    ShortcutRow(entry: entry)
                    if idx < group.entries.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))

            if let note = group.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }
        }
    }
}

private struct ShortcutRow: View {
    let entry: ShortcutEntry

    var body: some View {
        HStack(spacing: 12) {
            SnapThumbnail(region: entry.region, symbol: entry.symbol)
            Text(entry.action)
                .font(.body)
            Spacer(minLength: 8)
            Text(entry.shortcut)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.background, in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

/// A tiny screen outline with the target region highlighted — a glance-able
/// preview of where the window will land for a given shortcut.
private struct SnapThumbnail: View {
    let region: CGRect?
    let symbol: String?

    private let w: CGFloat = 38
    private let h: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(.quaternary)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)

            if let region {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width:  max(3, w * region.width  - 3),
                           height: max(3, h * region.height - 3))
                    .position(x: w * region.midX, y: h * region.midY)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: w, height: h)
    }
}
