import EventKit
import SwiftUI
import Combine

// MARK: - EventKit Service
class EventKitService: ObservableObject {
    static let shared = EventKitService()
    
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendars: [EKCalendar] = []
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    authorizationStatus = granted ? .fullAccess : .denied
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    authorizationStatus = granted ? .authorized : .denied
                }
                return granted
            }
        } catch {
            print("無法取得行事曆存取權限: \(error)")
            return false
        }
    }
    
    // MARK: - Calendar Management
    
    func fetchCalendars() {
        calendars = eventStore.calendars(for: .event)
    }
    
    // MARK: - Event Fetching
    
    func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]? = nil) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        return eventStore.events(matching: predicate)
    }
    
    func fetchEvents(for date: Date, calendars: [EKCalendar]? = nil) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return fetchEvents(from: startOfDay, to: endOfDay, calendars: calendars)
    }
    
    // MARK: - Event CRUD
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendar: EKCalendar? = nil,
        location: String? = nil,
        url: URL? = nil,
        notes: String? = nil
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        event.location = location
        event.url = url
        event.notes = notes
        
        try eventStore.save(event, span: .thisEvent)
        return event
    }
    
    func deleteEvent(_ event: EKEvent) throws {
        try eventStore.remove(event, span: .thisEvent)
    }
    
    func deleteEvent(withId identifier: String) async throws {
        // Need to allow access first? assuming caller has access
        if let event = eventStore.event(withIdentifier: identifier) {
            try eventStore.remove(event, span: .thisEvent)
        } else {
            // Event might already be deleted or not found
            // You might want to throw an error or just ignore
            print("Event not found for deletion: \(identifier)")
        }
    }
    
    func updateEvent(
        identifier: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendar: EKCalendar? = nil,
        location: String? = nil,
        url: URL? = nil,
        notes: String? = nil
    ) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            print("Event not found for update: \(identifier)")
            return
        }
        
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        if let calendar = calendar {
            event.calendar = calendar
        }
        event.location = location
        event.url = url
        event.notes = notes
        
        try eventStore.save(event, span: .thisEvent)
    }
}
