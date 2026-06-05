import SwiftUI
import ServiceManagement

// MARK: - Data model

struct ShortcutEntry: Identifiable {
    let id   = UUID()
    let action:   String
    let shortcut: String
}

struct ShortcutGroup: Identifiable {
    let id      = UUID()
    let title:   String
    let entries: [ShortcutEntry]
}

private let shortcutGroups: [ShortcutGroup] = [
    ShortcutGroup(title: "Halves", entries: [
        ShortcutEntry(action: "Left Half",    shortcut: "⌃⌥←"),
        ShortcutEntry(action: "Right Half",   shortcut: "⌃⌥→"),
        ShortcutEntry(action: "Top Half",     shortcut: "⌃⌥↑"),
        ShortcutEntry(action: "Bottom Half",  shortcut: "⌃⌥↓"),
    ]),
    ShortcutGroup(title: "Fullscreen", entries: [
        ShortcutEntry(action: "Maximize",     shortcut: "⌃⌥↩"),
    ]),
    ShortcutGroup(title: "Quarters", entries: [
        ShortcutEntry(action: "Top Left",     shortcut: "⌃⌥U"),
        ShortcutEntry(action: "Top Right",    shortcut: "⌃⌥I"),
        ShortcutEntry(action: "Bottom Left",  shortcut: "⌃⌥J"),
        ShortcutEntry(action: "Bottom Right", shortcut: "⌃⌥K"),
    ]),
    ShortcutGroup(title: "Thirds", entries: [
        ShortcutEntry(action: "Left Third",       shortcut: "⌃⌥D"),
        ShortcutEntry(action: "Center Third",     shortcut: "⌃⌥F"),
        ShortcutEntry(action: "Right Third",      shortcut: "⌃⌥G"),
        ShortcutEntry(action: "Left Two-Thirds",  shortcut: "⌃⌥E"),
        ShortcutEntry(action: "Right Two-Thirds", shortcut: "⌃⌥T"),
    ]),
    ShortcutGroup(title: "3×3 Grid (keypad)", entries: [
        ShortcutEntry(action: "Top Left",      shortcut: "⌃⌥7"),
        ShortcutEntry(action: "Top Center",    shortcut: "⌃⌥8"),
        ShortcutEntry(action: "Top Right",     shortcut: "⌃⌥9"),
        ShortcutEntry(action: "Middle Left",   shortcut: "⌃⌥4"),
        ShortcutEntry(action: "Middle Center", shortcut: "⌃⌥5"),
        ShortcutEntry(action: "Middle Right",  shortcut: "⌃⌥6"),
        ShortcutEntry(action: "Bottom Left",   shortcut: "⌃⌥1"),
        ShortcutEntry(action: "Bottom Center", shortcut: "⌃⌥2"),
        ShortcutEntry(action: "Bottom Right",  shortcut: "⌃⌥3"),
        ShortcutEntry(action: "Arrange All Windows", shortcut: "⌃⌥0"),
    ]),
    ShortcutGroup(title: "Displays", entries: [
        ShortcutEntry(action: "Next Display",     shortcut: "⌃⌥⇧→"),
        ShortcutEntry(action: "Previous Display", shortcut: "⌃⌥⇧←"),
    ]),
]

// MARK: - Views

struct PreferencesView: View {
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            shortcutList
            Divider()
            loginToggle
        }
        .frame(width: 340)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.3.group")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text("Gridly")
                .font(.title2.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: Shortcut list

    private var shortcutList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(shortcutGroups) { group in
                    GroupSection(group: group)
                }
            }
            .padding(20)
        }
        .frame(maxHeight: 420)
    }

    // MARK: Launch at login

    private var loginToggle: some View {
        HStack {
            Text("Launch at Login")
                .font(.body)
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !enabled   // revert if it failed
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Sub-views

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
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct ShortcutRow: View {
    let entry: ShortcutEntry

    var body: some View {
        HStack {
            Text(entry.action)
                .font(.body)
            Spacer()
            Text(entry.shortcut)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.background, in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
