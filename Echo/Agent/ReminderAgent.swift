import Foundation
import EventKit

// MARK: - Reminder and Calendar operations via EventKit

actor ReminderAgent {
    private let store = EKEventStore()

    // MARK: - Permission

    func requestRemindersAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if status == .fullAccess { return true }
        if status == .denied || status == .restricted { return false }
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func requestCalendarAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess { return true }
        if status == .denied || status == .restricted { return false }
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // MARK: - Reminders

    func fetchReminders(in lists: [EKCalendar]? = nil) async throws -> [EKReminder] {
        guard await requestRemindersAccess() else {
            throw EchoAgentError.permissionDenied("Reminders")
        }
        let calendars = lists ?? store.calendars(for: .reminder)
        return try await withCheckedThrowingContinuation { cont in
            store.fetchReminders(matching: store.predicateForReminders(in: calendars)) { reminders in
                cont.resume(returning: reminders ?? [])
            }
        }
    }

    func createReminder(title: String, dueDate: Date?, notes: String? = nil) async throws {
        guard await requestRemindersAccess() else {
            throw EchoAgentError.permissionDenied("Reminders")
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        reminder.notes = notes

        if let due = dueDate {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            reminder.dueDateComponents = comps
            reminder.alarms = [EKAlarm(absoluteDate: due)]
        }
        try store.save(reminder, commit: true)
    }

    func deleteReminder(calendarItemID: String) async throws {
        guard await requestRemindersAccess() else {
            throw EchoAgentError.permissionDenied("Reminders")
        }
        guard let reminder = store.calendarItem(withIdentifier: calendarItemID) as? EKReminder else {
            throw EchoAgentError.notFound("Reminder")
        }
        try store.remove(reminder, commit: true)
    }

    // MARK: - Calendar events

    func createEvent(title: String, start: Date, end: Date, notes: String? = nil) async throws {
        guard await requestCalendarAccess() else {
            throw EchoAgentError.permissionDenied("Calendar")
        }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent, commit: true)
    }

    func fetchUpcomingEvents(days: Int = 7) async throws -> [EKEvent] {
        guard await requestCalendarAccess() else {
            throw EchoAgentError.permissionDenied("Calendar")
        }
        let start = Date.now
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start

        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
}
