import Foundation
import Observation
import EventKit
import AppKit

@Observable
final class CalendarStore {
    struct Entry: Identifiable, Hashable {
        let id: String
        var title: String
        var start: Date
        var end: Date
        var isAllDay: Bool
        var color: NSColor?

        var isNow: Bool {
            let now = Date()
            return start <= now && now <= end
        }
    }

    private(set) var entries: [Entry] = []
    private(set) var accessGranted = false

    func applyDemo(_ demo: [Entry]) {
        entries = demo
        accessGranted = true
    }
    var anchor = Date()
    var selectedDay: Date?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var requestInFlight = false
    @ObservationIgnored private var hasRequested = false
    @ObservationIgnored private var tick = 0

    func start() {
        refreshAuthorization()

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.reload() }
        }

        let timer = Timer(timeInterval: 5, repeats: true) { _ in
            MainActor.assumeIsolated {
                if self.accessGranted {
                    self.tick += 1
                    if self.tick % 60 == 0 { self.reload() }
                } else {
                    self.refreshAuthorization()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    var needsPermission: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    func requestAccess() {
        guard !requestInFlight else { return }
        requestInFlight = true
        let restore = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        Task { [weak self] in
            guard let self else { return }
            do {
                let granted = try await store.requestFullAccessToEvents()
                accessGranted = granted
                if granted { reload() }
            } catch {
                accessGranted = false
            }
            NSApp.setActivationPolicy(restore)
            requestInFlight = false
        }
    }

    private func refreshAuthorization() {
        guard !Debug.isDemo else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            if !accessGranted {
                accessGranted = true
                reload()
            }
        case .notDetermined:
            guard !hasRequested else { return }
            hasRequested = true
            requestAccess()
        default:
            accessGranted = false
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func reload() {
        guard accessGranted else { return }
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start ?? now
        let monthEnd = calendar.dateInterval(of: .month, for: anchor)?.end ?? now
        let listStart = selectedDay.map { calendar.startOfDay(for: $0) } ?? now
        let listEnd = calendar.date(byAdding: .day, value: 7, to: listStart) ?? listStart
        let start = min(now, monthStart, listStart)
        let end = max(monthEnd, listEnd)

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        entries = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                Entry(id: $0.eventIdentifier ?? UUID().uuidString,
                      title: $0.title ?? "(no title)",
                      start: $0.startDate,
                      end: $0.endDate,
                      isAllDay: $0.isAllDay,
                      color: $0.calendar?.color)
            }
    }

    // MARK: - Editing

    struct Draft {
        var eventID: String?
        var title = ""
        var start = Date()
        var end = Date().addingTimeInterval(3600)
        var isAllDay = false
        var calendarID: String?
        var location = ""
        var notes = ""
        var isReadOnly = false
        var isRecurring = false

        var isNew: Bool { eventID == nil }
    }

    struct CalendarChoice: Identifiable, Hashable {
        let id: String
        var title: String
        var color: NSColor?
    }

    var draft: Draft?
    private(set) var saveError: String?

    var writableCalendars: [CalendarChoice] {
        store.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title, color: $0.color) }
            .sorted { $0.title < $1.title }
    }

    func compose() {
        let calendar = Calendar.current
        let day = selectedDay ?? Date()
        let base = calendar.isDateInToday(day) ? Date() : calendar.startOfDay(for: day).addingTimeInterval(9 * 3600)
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: base)
        components.hour = (components.hour ?? 9) + (calendar.isDateInToday(day) ? 1 : 0)
        components.minute = 0
        let start = calendar.date(from: components) ?? base
        saveError = nil
        draft = Draft(start: start,
                      end: start.addingTimeInterval(3600),
                      calendarID: store.defaultCalendarForNewEvents?.calendarIdentifier)
    }

    func edit(_ entry: Entry) {
        saveError = nil
        guard let event = store.event(withIdentifier: entry.id) else {
            draft = Draft(eventID: entry.id, title: entry.title, start: entry.start,
                          end: entry.end, isAllDay: entry.isAllDay, isReadOnly: true)
            return
        }
        draft = Draft(eventID: entry.id,
                      title: event.title ?? "",
                      start: event.startDate,
                      end: event.endDate,
                      isAllDay: event.isAllDay,
                      calendarID: event.calendar?.calendarIdentifier,
                      location: event.location ?? "",
                      notes: event.notes ?? "",
                      isReadOnly: !(event.calendar?.allowsContentModifications ?? false),
                      isRecurring: event.hasRecurrenceRules)
    }

    func cancelEdit() {
        draft = nil
        saveError = nil
    }

    func commit() {
        guard var draft, !draft.isReadOnly else { return }
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveError = "Give the event a title"
            return
        }
        if draft.end <= draft.start {
            draft.end = draft.start.addingTimeInterval(3600)
        }

        let event: EKEvent
        if let id = draft.eventID, let existing = store.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }
        event.title = trimmed
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.isAllDay
        event.location = draft.location.isEmpty ? nil : draft.location
        event.notes = draft.notes.isEmpty ? nil : draft.notes
        if event.calendar == nil || draft.eventID == nil {
            event.calendar = draft.calendarID.flatMap { id in
                store.calendars(for: .event).first { $0.calendarIdentifier == id }
            } ?? store.defaultCalendarForNewEvents
        }
        guard event.calendar != nil else {
            saveError = "No writable calendar available"
            return
        }

        do {
            try store.save(event, span: .thisEvent, commit: true)
            self.draft = nil
            saveError = nil
            reload()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func deleteEditedEvent() {
        guard let draft, let id = draft.eventID, !draft.isReadOnly,
              let event = store.event(withIdentifier: id) else { return }
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            self.draft = nil
            saveError = nil
            reload()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var upcoming: [Entry] {
        let calendar = Calendar.current
        let start = selectedDay.map { calendar.startOfDay(for: $0) } ?? Date()
        let horizon = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return entries.filter { $0.end >= start && $0.start <= horizon }
    }

    var windowStart: Date {
        selectedDay.map { Calendar.current.startOfDay(for: $0) } ?? Date()
    }

    func select(_ day: Date) {
        let calendar = Calendar.current
        if let current = selectedDay, calendar.isDate(current, inSameDayAs: day) {
            selectedDay = nil
        } else {
            selectedDay = day
        }
        reload()
    }

    func hasEvents(on day: Date) -> Bool {
        let calendar = Calendar.current
        return entries.contains { calendar.isDate($0.start, inSameDayAs: day) }
    }

    func shiftMonth(by value: Int) {
        guard let moved = Calendar.current.date(byAdding: .month, value: value, to: anchor) else { return }
        anchor = moved
        reload()
    }
}
