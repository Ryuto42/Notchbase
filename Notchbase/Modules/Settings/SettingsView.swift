import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(L.t("General"), systemImage: "gearshape") }
            AppearanceSettings()
                .tabItem { Label(L.t("Appearance"), systemImage: "paintbrush") }
            ModuleSettings()
                .tabItem { Label(L.t("Modules"), systemImage: "square.grid.2x2") }
            AboutSettings()
                .tabItem { Label(L.t("About"), systemImage: "info.circle") }
        }
        .frame(width: 500, height: 520)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @State private var prefs = Preferences.shared
    @State private var updates = UpdateController.shared

    private var lastCheckText: String {
        guard let date = updates.lastCheck else { return L.t("Never") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        Form {
            Section {
                Toggle(L.t("Launch at login"), isOn: $prefs.launchAtLogin)
                Picker(L.t("Language"), selection: $prefs.language) {
                    ForEach(Preferences.Language.allCases) { option in
                        Text(L.t(option.title)).tag(option)
                    }
                }
                Hint(L.t("Applies to the panel and this window."))
                Picker(L.t("Open on"), selection: $prefs.defaultTab) {
                    ForEach(prefs.visibleTabs) { tab in
                        Label(tab.title, systemImage: tab.symbol).tag(tab)
                    }
                }
                Hint(L.t("The tab the panel starts on each time you open it."))
            }

            Section(L.t("Updates")) {
                Toggle(L.t("Check for updates automatically"), isOn: $updates.automaticallyChecks)
                Toggle(L.t("Download and install automatically"), isOn: $updates.automaticallyDownloads)
                    .disabled(!updates.automaticallyChecks)
                LabeledContent(L.t("Last checked"), value: lastCheckText)
                Button(L.t("Check now")) { updates.checkNow() }
                    .disabled(!updates.canCheck)
                Hint(L.t("Updates are downloaded from the project's GitHub releases and verified before installing."))
            }

            Section(L.t("Opening")) {
                SliderRow(title: L.t("Hover delay"),
                          value: Binding(get: { Double(prefs.hoverDelayMs) },
                                         set: { prefs.hoverDelayMs = Int($0) }),
                          range: 0...600, step: 25, format: "%.0f ms")
                Hint(L.t("How long the pointer rests on the notch before the panel opens. A short delay stops it firing when you reach for the menu bar."))

                SliderRow(title: L.t("Tab hover delay"),
                          value: Binding(get: { Double(prefs.tabHoverDelayMs) },
                                         set: { prefs.tabHoverDelayMs = Int($0) }),
                          range: 0...400, step: 10, format: "%.0f ms")

                SliderRow(title: L.t("Resume window"), value: $prefs.resumeSeconds,
                          range: 0...30, step: 1, format: "%.0f s")
                Hint(L.t("Reopening within this time keeps the tab you were last on. Set to 0 to always start on the tab above."))
            }

            Section(L.t("Activity strip")) {
                Toggle(L.t("Show when closed"), isOn: $prefs.showActivityStrip)
                Picker(L.t("Priority"), selection: $prefs.activityPriority) {
                    ForEach(Preferences.ActivityPriority.allCases) { option in
                        Text(L.t(option.title)).tag(option)
                    }
                }
                .disabled(!prefs.showActivityStrip)
                SliderRow(title: L.t("Announce for"), value: $prefs.announceSeconds,
                          range: 3...30, step: 1, format: "%.0f s")
                    .disabled(!prefs.showActivityStrip)
                Hint(L.t("How long a finished agent keeps the strip before it hands back to whatever else is showing."))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @State private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section(L.t("Tabs")) {
                TabOrderList(prefs: prefs)
                Hint(L.t("Drag to reorder. Unticked tabs are hidden from the switcher."))
            }

            Section(L.t("Lower edge")) {
                Toggle(L.t("Fade into the desktop"), isOn: $prefs.bottomFade)
                SliderRow(title: L.t("Amount"), value: $prefs.bottomFadeAmount,
                          range: 0.2...0.9, step: 0.05, format: "%.0f%%", scale: 100)
                    .disabled(!prefs.bottomFade)
                Hint(L.t("The bottom of the panel dissolves into glass so it does not end on a hard edge. Turn it off for a solid panel."))
            }

            Section(L.t("Tab switcher")) {
                SliderRow(title: L.t("Transparency"), value: $prefs.tabRailOpacity,
                          range: 0.25...1, step: 0.02, format: "%.0f%%", scale: 100)
                Hint(L.t("How solid the switcher looks. Icons and labels stay readable at any setting."))
                Toggle(L.t("Clear glass"), isOn: $prefs.clearGlassRail)
                Hint(L.t("Clear glass lets more of the desktop through than the regular material."))
                Toggle(L.t("Show label on the selected tab"), isOn: $prefs.showTabLabels)
            }

            Section(L.t("Motion")) {
                Picker(L.t("Animation"), selection: $prefs.motionStyle) {
                    ForEach(Preferences.MotionStyle.allCases) { style in
                        Text(L.t(style.title)).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Hint(L.t("Scales every spring in the app. Snappy is roughly 30% quicker than balanced; calm is about 45% slower."))

                SliderRow(title: L.t("Bounce"), value: $prefs.motionBounce,
                          range: 0...2.5, step: 0.1, format: "%.1f×")
                Hint(L.t("0 removes overshoot entirely and everything eases to a stop. Higher values let the panel and the tab switcher spring past their target before settling."))
            }
        }
        .formStyle(.grouped)
    }
}

private struct TabOrderList: View {
    @Bindable var prefs: Preferences

    private var order: [NotchTab] {
        prefs.tabOrder.isEmpty ? NotchTab.allCases : prefs.tabOrder
    }

    var body: some View {
        List {
            ForEach(order) { tab in
                HStack {
                    Toggle(isOn: Binding(
                        get: { !prefs.hiddenTabs.contains(tab) },
                        set: { shown in
                            if shown {
                                prefs.hiddenTabs.remove(tab)
                            } else if prefs.visibleTabs.count > 1 {
                                prefs.hiddenTabs.insert(tab)
                            }
                        })) {
                            Label(tab.title, systemImage: tab.symbol)
                        }
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                }
            }
            .onMove { indices, destination in
                var updated = order
                updated.move(fromOffsets: indices, toOffset: destination)
                prefs.tabOrder = updated
            }
        }
        .frame(height: 190)
        .scrollDisabled(true)
    }
}

// MARK: - Modules

private struct ModuleSettings: View {
    @State private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section(L.t("Tray")) {
                Toggle(L.t("Show AirDrop zone"), isOn: $prefs.showAirDropZone)
                Toggle(L.t("Copy dropped files into Notchbase"), isOn: $prefs.copyDroppedFiles)
                Hint(L.t(prefs.copyDroppedFiles
                     ? "Files are duplicated, so moving the original does not break the tray."
                     : "Only a reference is kept; moving or deleting the original removes the item."))
            }

            Section(L.t("Clipboard")) {
                Toggle(L.t("Record history"), isOn: $prefs.clipboardEnabled)
                Stepper(L.count("Keep %@ items", prefs.clipboardLimit),
                        value: $prefs.clipboardLimit, in: 20...1000, step: 20)
                    .disabled(!prefs.clipboardEnabled)
                Hint(L.t("Items marked concealed or transient — password managers use these — are never recorded."))
            }

            Section(L.t("Media")) {
                Toggle(L.t("Fetch lyrics from LRCLIB"), isOn: $prefs.lyricsEnabled)
                SliderRow(title: L.t("Lyric offset"), value: $prefs.lyricsOffset,
                          range: -3...3, step: 0.1, format: "%+.1f s")
                    .disabled(!prefs.lyricsEnabled)
                Stepper(L.count("Show %@ upcoming tracks", prefs.queueLimit),
                        value: $prefs.queueLimit, in: 3...12)
                Toggle(L.t("Colour from the album art"), isOn: $prefs.artworkAccent)
                Hint(L.t("The playing bars and the scrubber take their colour from the current cover. Artwork with no colour in it falls back to the standard blue."))
                SpotifySettings()
            }

            Section(L.t("Agents")) {
                Picker(L.t("Resume in"), selection: $prefs.sessionTarget) {
                    ForEach(Preferences.SessionTarget.installed) { target in
                        Text(L.t(target.title)).tag(target)
                    }
                }
                Stepper(L.count("Show the last %@ days", prefs.agentHistoryDays),
                        value: $prefs.agentHistoryDays, in: 1...14)
                Hint(L.t("Sessions are read from Claude Code and Codex transcripts on disk. Clicking one resumes it in the terminal."))
            }

            Section(L.t("Terminal")) {
                TextField(L.t("Shell"), text: $prefs.terminalShell)
                Hint(L.t("Takes effect the next time Notchbase launches."))
            }
        }
        .formStyle(.grouped)
    }
}

private struct SpotifySettings: View {
    @State private var auth = SpotifyAuth.shared
    @State private var copied = false

    var body: some View {
        LabeledContent(L.t("Spotify queue")) {
            switch auth.status {
            case .connected:
                HStack {
                    Label(L.t("Connected"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button(L.t("Disconnect")) { auth.disconnect() }
                }
            case .waitingForBrowser:
                HStack {
                    ProgressView().controlSize(.small)
                    Text(L.t("Waiting for the browser…"))
                    Spacer()
                    Button(L.t("Cancel")) { auth.cancel() }
                }
            case .failed(let message):
                HStack {
                    Text(L.t(message)).foregroundStyle(.orange).lineLimit(3)
                    Spacer()
                    Button(L.t("Retry")) { auth.connect() }
                        .disabled(!auth.isClientIDPlausible)
                }
            case .disconnected:
                Button(L.t("Connect")) { auth.connect() }
                    .disabled(!auth.isClientIDPlausible)
            }
        }

        if auth.status != .connected {
            LabeledContent(L.t("Step 1")) {
                HStack {
                    Text(L.t("Register a free app on Spotify"))
                    Spacer()
                    Button(L.t("Open dashboard")) {
                        NSWorkspace.shared.open(SpotifyAuth.dashboardURL)
                    }
                }
            }

            LabeledContent(L.t("Step 2")) {
                HStack {
                    Text(SpotifyAuth.redirectURI)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(copied ? L.t("Copied") : L.t("Copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(SpotifyAuth.redirectURI, forType: .string)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    }
                }
            }
            Hint(L.t("Paste this as the app's Redirect URI and tick the Web API."))
        }

        LabeledContent(L.t("Step 3")) {
            HStack {
                TextField(L.t("Client ID"), text: $auth.clientID)
                    .textFieldStyle(.roundedBorder)
                if !auth.clientID.isEmpty {
                    Image(systemName: auth.isClientIDPlausible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(auth.isClientIDPlausible ? .green : .orange)
                }
            }
        }

        Hint(L.t("Optional — only the queue needs it. Notchbase asks for the user-read-playback-state scope and nothing else; there is no client secret to store."))
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                LabeledContent(L.t("Requires"), value: L.t("macOS 15 or later"))
            }

            Section(L.t("Permissions")) {
                PermissionRow(name: "Automation",
                              detail: L.t("Reads what Music and Spotify are playing."),
                              pane: "Privacy_Automation")
                PermissionRow(name: "Calendar",
                              detail: L.t("Shows your upcoming events."),
                              pane: "Privacy_Calendars")
                Hint(L.t("Notchbase is not sandboxed and is signed ad-hoc by default. macOS ties these grants to the code signature, so they reset on every rebuild unless you sign with a stable development certificate."))
            }

            Section(L.t("Third party")) {
                LabeledContent(L.t("Updates"), value: "Sparkle (MIT)")
                LabeledContent(L.t("Terminal"), value: L.t("SwiftTerm (MIT)"))
                LabeledContent(L.t("Lyrics"), value: L.t("LRCLIB — no account required"))
                LabeledContent(L.t("Icons"), value: L.t("Simple Icons (CC0); trademarks belong to their owners"))
            }

            Section {
                Button(L.t("Reset all settings")) { Preferences.shared.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionRow: View {
    var name: String
    var detail: String
    var pane: String

    var body: some View {
        LabeledContent(name) {
            HStack {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L.t("Open")) {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
                }
            }
        }
    }
}

// MARK: - Shared controls

private struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var format: String
    var scale: Double = 1

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range, step: step)
                Text(String(format: format, value * scale))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .trailing)
            }
        }
    }
}

private struct Hint: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
