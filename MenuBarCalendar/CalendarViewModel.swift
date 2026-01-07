import SwiftUI
import Combine
import EventKit

// MARK: - Calendar ViewModel
class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var selectedDate: Date = Date()
    @Published var events: [CalendarEvent] = []
    @Published var days: [CalendarDay] = []
    @Published var isLoadingEvents = false
    @Published var hasCalendarAccess = false
    
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    private let eventKitService = EventKitService.shared
    
    init() {
        generateDays()
        checkCalendarAccess()
        
        $currentMonth
            .sink { [weak self] _ in
                self?.generateDays()
                self?.loadEventsFromEventKit()
            }
            .store(in: &cancellables)
        
        $selectedDate
            .sink { [weak self] _ in
                self?.loadEventsFromEventKit()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentMonth)
    }
    
    var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: selectedDate)
    }
    
    var selectedDateEvents: [CalendarEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { ($0.time ?? Date.distantPast) < ($1.time ?? Date.distantPast) }
    }
    
    // MARK: - Navigation
    
    func previousMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    func nextMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = Date()
            selectedDate = Date()
        }
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    // MARK: - Day Helpers
    
    func isSelected(_ day: CalendarDay) -> Bool {
        calendar.isDate(day.date, inSameDayAs: selectedDate)
    }
    
    func isToday(_ day: CalendarDay) -> Bool {
        calendar.isDateInToday(day.date)
    }
    
    func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    // MARK: - Event Management
    
    func addEvent(_ event: CalendarEvent) {
        Task {
            do {
                // Convert CalendarEvent to EventKit event
                let startDate: Date
                let endDate: Date
                
                if event.isAllDay {
                    startDate = calendar.startOfDay(for: event.date)
                    endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                } else if let time = event.time {
                    startDate = combineDateTime(date: event.date, time: time)
                    endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
                } else {
                    startDate = calendar.startOfDay(for: event.date)
                    endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
                }
                
                let _ = try eventKitService.createEvent(
                    title: event.title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: event.isAllDay,
                    notes: event.notes
                )
                
                await MainActor.run {
                    events.append(event)
                    loadEventsFromEventKit()
                }
            } catch {
                print("無法建立事件: \(error)")
            }
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) {
        events.removeAll { $0.id == event.id }
    }
    
    // MARK: - EventKit Integration
    
    func checkCalendarAccess() {
        eventKitService.checkAuthorizationStatus()
        let status = eventKitService.authorizationStatus
        
        if #available(macOS 14.0, *) {
            hasCalendarAccess = (status == .fullAccess)
        } else {
            hasCalendarAccess = (status == .authorized)
        }
        
        if hasCalendarAccess {
            loadEventsFromEventKit()
        }
    }
    
    func requestCalendarAccess() {
        Task {
            let granted = await eventKitService.requestAccess()
            await MainActor.run {
                hasCalendarAccess = granted
                if granted {
                    loadEventsFromEventKit()
                }
            }
        }
    }
    
    func loadEventsFromEventKit() {
        guard hasCalendarAccess else { return }
        
        isLoadingEvents = true
        
        // Load events for the current month
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let ekEvents = eventKitService.fetchEvents(from: startOfMonth, to: endOfMonth)
        
        // Convert EKEvent to CalendarEvent
        events = ekEvents.compactMap { ekEvent in
            guard let title = ekEvent.title,
                  let startDate = ekEvent.startDate else {
                return nil
            }
            
            return CalendarEvent(
                title: title,
                date: calendar.startOfDay(for: startDate),
                time: ekEvent.isAllDay ? nil : startDate,
                color: colorForCalendar(ekEvent.calendar),
                isAllDay: ekEvent.isAllDay,
                notes: ekEvent.notes,
                reminder: .none
            )
        }
        
        isLoadingEvents = false
    }
    
    private func colorForCalendar(_ ekCalendar: EKCalendar) -> Color {
        // Convert CGColor to SwiftUI Color
        if let cgColor = ekCalendar.cgColor {
            return Color(cgColor)
        }
        return .blue // Default color
    }
    
    private func combineDateTime(date: Date, time: Date) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? date
    }
    
    // MARK: - Private Methods
    
    private func generateDays() {
        var result: [CalendarDay] = []
        
        let year = calendar.component(.year, from: currentMonth)
        let month = calendar.component(.month, from: currentMonth)
        
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysInMonth = range.count
        
        // Previous month days
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
        let previousMonthRange = calendar.range(of: .day, in: .month, for: previousMonth)!
        let previousMonthDays = previousMonthRange.count
        
        for i in 0..<(firstWeekday - 1) {
            let day = previousMonthDays - (firstWeekday - 2) + i
            if let date = calendar.date(from: DateComponents(year: year, month: month - 1, day: day)) {
                result.append(CalendarDay(day: day, date: date, isCurrentMonth: false, isWeekend: isWeekend(date)))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                result.append(CalendarDay(day: day, date: date, isCurrentMonth: true, isWeekend: isWeekend(date)))
            }
        }
        
        // Next month days
        let remainingDays = 42 - result.count
        for day in 1...remainingDays {
            if let date = calendar.date(from: DateComponents(year: year, month: month + 1, day: day)) {
                result.append(CalendarDay(day: day, date: date, isCurrentMonth: false, isWeekend: isWeekend(date)))
            }
        }
        
        days = result
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}
