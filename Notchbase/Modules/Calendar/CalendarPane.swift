import SwiftUI

struct CalendarPane: View {
    var store: CalendarStore

    var body: some View {
        if !store.accessGranted {
            if store.needsPermission {
                PlaceholderView(symbol: "calendar.badge.exclamationmark",
                                title: L.t("Calendar access needed"),
                                detail: L.t("Notchbase needs permission to read your events."),
                                actionTitle: L.t("Allow access")) {
                    store.requestAccess()
                }
            } else {
                PlaceholderView(symbol: "calendar.badge.exclamationmark",
                                title: L.t("Calendar access needed"),
                                detail: L.t("Allow Notchbase under Privacy & Security › Calendars."),
                                actionTitle: L.t("Open Privacy Settings")) {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                }
            }
        } else if store.draft != nil {
            EventEditor(store: store)
                .padding(.horizontal, 12)
                .padding(.top, 7)
                .padding(.bottom, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
        } else {
            HStack(spacing: 0) {
                MonthGrid(store: store)
                    .frame(width: 244)

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1)
                    .padding(.vertical, 6)

                UpcomingList(store: store)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
    }
}

// MARK: - Month

private struct MonthGrid: View {
    var store: CalendarStore

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    /// Always six weeks: a month that needs five rows would otherwise resize the panel.
    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: store.anchor) else { return [] }
        let first = interval.start
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let dates = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        var cells: [Date?] = Array(repeating: nil, count: leading) + dates.map { Optional($0) }
        cells.append(contentsOf: Array(repeating: nil, count: max(0, 42 - cells.count)))
        return cells
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var body: some View {
        VStack(spacing: 3) {
            header
            HStack(spacing: 1) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Typo.rounded(8.5, .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    DayCell(day: day, store: store)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.trailing, 12)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(store.anchor.formatted(.dateTime.year().month(.wide)))
                .font(Typo.rounded(12, .semibold))
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 0)
            GlyphButton(symbol: "chevron.left", size: 9) { store.shiftMonth(by: -1) }
            GlyphButton(symbol: "chevron.right", size: 9) { store.shiftMonth(by: 1) }
            GlyphButton(symbol: "plus", size: 10) { store.compose() }
                .help(L.t("New event"))
        }
    }
}

private struct DayCell: View {
    var day: Date?
    var store: CalendarStore

    @State private var hovering = false

    private let calendar = Calendar.current

    var body: some View {
        if let day {
            let isToday = calendar.isDateInToday(day)
            let isSelected = store.selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

            Button {
                store.select(day)
            } label: {
                VStack(spacing: 1.5) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(Typo.digits(10.5, isToday || isSelected ? .bold : .medium))
                        .foregroundStyle(isToday ? .black : Theme.primaryText)
                    Circle()
                        .fill(store.hasEvents(on: day) ? (isToday ? .black : Theme.accent) : .clear)
                        .frame(width: 3, height: 3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background {
                    if isToday {
                        Circle().fill(Theme.accent).frame(width: 22, height: 22)
                    } else if hovering {
                        Circle().fill(Color.white.opacity(0.12)).frame(width: 22, height: 22)
                    }
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Theme.warm, lineWidth: 1.4)
                            .frame(width: 22, height: 22)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        } else {
            Color.clear.frame(height: 22)
        }
    }
}

// MARK: - Upcoming

private struct UpcomingList: View {
    var store: CalendarStore

    /// L.t("Upcoming") while anchored to now, otherwise the week the tapped day opens.
    private var headline: String {
        guard let selected = store.selectedDay else { return L.t("Upcoming") }
        let end = Calendar.current.date(byAdding: .day, value: 6, to: selected) ?? selected
        let from = selected.formatted(.dateTime.month(.abbreviated).day())
        let to = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(from) – \(to)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(headline)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                if store.selectedDay != nil {
                    Button {
                        store.selectedDay = nil
                        store.reload()
                    } label: {
                        Text(L.t("Today"))
                            .font(Typo.rounded(9.5, .semibold))
                            .foregroundStyle(Theme.warm)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.top, 2)

            if store.upcoming.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .light))
                    Text(L.t("Nothing in the next week"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(store.upcoming) { entry in
                            EventRow(entry: entry) { store.edit(entry) }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

private struct EventRow: View {
    var entry: CalendarStore.Entry
    var open: () -> Void

    @State private var hovering = false

    private var accent: Color {
        entry.color.map(Color.init) ?? Theme.accent
    }

    var body: some View {
        Button(action: open) { row }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
    }

    private var row: some View {
        HStack(spacing: 9) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(entry.start.formatted(.dateTime.month(.abbreviated).day()))
                    .font(Typo.rounded(9, .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                if entry.isAllDay {
                    Text("all day")
                        .font(Typo.rounded(9))
                        .foregroundStyle(Theme.tertiaryText)
                } else {
                    Text(entry.start.formatted(date: .omitted, time: .shortened))
                        .font(Typo.digits(10.5))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(width: 52, alignment: .trailing)

            Capsule()
                .fill(entry.isNow ? Theme.warm : accent)
                .frame(width: 2.5, height: 26)

            Text(entry.title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .cardBackground(hovering: hovering, radius: 9)
        .contentShape(Rectangle())
    }
}

// MARK: - Editor

/// Compose, edit or delete a single event. It takes over the whole pane rather than
/// floating over it: at this size a sheet would leave nothing legible behind it.
private struct EventEditor: View {
    @Bindable var store: CalendarStore

    @State private var confirmingDelete = false

    private var draft: Binding<CalendarStore.Draft> {
        Binding(get: { store.draft ?? CalendarStore.Draft() },
                set: { store.draft = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            fields
            notes
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(store.draft?.isNew == true ? L.t("New event") : L.t("Edit event"))
                .font(Typo.rounded(12, .semibold))
                .foregroundStyle(Theme.primaryText)
            if store.draft?.isRecurring == true {
                Label(L.t("Repeats"), systemImage: "repeat")
                    .font(Typo.rounded(9, .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
            if let error = store.saveError {
                Text(L.t(error))
                    .font(Typo.rounded(10))
                    .foregroundStyle(Theme.warm)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        let readOnly = store.draft?.isReadOnly ?? false

        TextField(L.t("Title"), text: draft.title)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .cardBackground(radius: 8)
            .disabled(readOnly)

        HStack(spacing: 8) {
            DatePicker("", selection: draft.start,
                       displayedComponents: draft.isAllDay.wrappedValue ? [.date] : [.date, .hourAndMinute])
                .labelsHidden()
            Text("→").foregroundStyle(Theme.tertiaryText)
            DatePicker("", selection: draft.end,
                       displayedComponents: draft.isAllDay.wrappedValue ? [.date] : [.date, .hourAndMinute])
                .labelsHidden()
            Toggle(L.t("All day"), isOn: draft.isAllDay)
                .toggleStyle(.checkbox)
                .font(Typo.rounded(10.5))
            Spacer(minLength: 0)
        }
        .controlSize(.small)
        .font(Typo.digits(11))
        .disabled(readOnly)

        HStack(spacing: 8) {
            TextField(L.t("Location"), text: draft.location)
                .textFieldStyle(.plain)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .cardBackground(radius: 8)

            if store.draft?.isNew == true, !store.writableCalendars.isEmpty {
                Picker("", selection: draft.calendarID) {
                    ForEach(store.writableCalendars) { choice in
                        Text(choice.title).tag(Optional(choice.id))
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 130)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.secondaryText)
        .disabled(readOnly)
    }

    private var notes: some View {
        TextEditor(text: draft.notes)
            .scrollContentBackground(.hidden)
            .font(.system(size: 11))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground(radius: 8)
            .overlay(alignment: .topLeading) {
                if draft.notes.wrappedValue.isEmpty {
                    Text(L.t("Notes"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)
                }
            }
            .disabled(store.draft?.isReadOnly ?? true)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if store.draft?.isNew == false, store.draft?.isReadOnly == false {
                if confirmingDelete {
                    Text(L.t("Delete this event?"))
                        .font(Typo.rounded(10.5))
                        .foregroundStyle(Theme.secondaryText)
                    TextButton(title: L.t("Delete")) { store.deleteEditedEvent() }
                    TextButton(title: L.t("Keep")) { confirmingDelete = false }
                } else {
                    TextButton(title: L.t("Delete")) { confirmingDelete = true }
                }
            }
            if store.draft?.isReadOnly == true {
                Text(L.t("This calendar is read-only."))
                    .font(Typo.rounded(10.5))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer(minLength: 0)
            TextButton(title: L.t("Cancel")) { store.cancelEdit() }
            Button(L.t("Save")) { store.commit() }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(store.draft?.isReadOnly ?? true)
        }
    }
}
