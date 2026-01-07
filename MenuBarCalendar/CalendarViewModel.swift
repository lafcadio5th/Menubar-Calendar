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
    
    @Published var availableCalendars: [EKCalendar] = []
    
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    private let eventKitService = EventKitService.shared
    
    // Store hidden calendar IDs in UserDefaults
    private var hiddenCalendarIDs: Set<String> {
        get {
            let ids = UserDefaults.standard.stringArray(forKey: "hiddenCalendarIDs") ?? []
            return Set(ids)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "hiddenCalendarIDs")
            objectWillChange.send()
            loadEventsFromEventKit() // Reload events when visibility changes
        }
    }
    
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
            
        // Listen for calendar changes
        eventKitService.$calendars
            .receive(on: RunLoop.main)
            .assign(to: \.availableCalendars, on: self)
            .store(in: &cancellables)
            
        // Listen for UserDefaults changes (for settings updates from other windows)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                // Only reload if relevant keys changed? 
                // For simplicity, we can just reload. But we should be careful about loops.
                // Actually, just checking if hiddenCalendarIDs changed might be enough, but that's expensive.
                // Let's just reload. It's a settings change, user expects update.
                self?.loadEventsFromEventKit()
                self?.generateDays() // reload days if startWeekOnMonday changed
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Calendar Management
    
    func isCalendarVisible(_ calendar: EKCalendar) -> Bool {
        !hiddenCalendarIDs.contains(calendar.calendarIdentifier)
    }
    
    func toggleCalendarVisibility(_ calendar: EKCalendar) {
        if hiddenCalendarIDs.contains(calendar.calendarIdentifier) {
            hiddenCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            hiddenCalendarIDs.insert(calendar.calendarIdentifier)
        }
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
                // Determine target calendar
                var targetCalendar: EKCalendar? = nil
                if let calId = event.calendarId {
                     // Since we don't expose eventKitService.calendars directly as a dictionary, search for it
                     // Or force fetch. But we have availableCalendars.
                     targetCalendar = availableCalendars.first { $0.calendarIdentifier == calId }
                }

                // Calculate dates
                let startDate: Date
                let endDate: Date
                
                if event.isAllDay {
                    startDate = calendar.startOfDay(for: event.date)
                    endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                } else if let time = event.time {
                    // Re-calculate start from date component + time component
                    let start = combineDateTime(date: event.date, time: time)
                    
                    // Simple logic: if event.endDate is set and > start, use it. Else +1h.
                    if event.endDate > start {
                        endDate = event.endDate
                    } else {
                        endDate = calendar.date(byAdding: .hour, value: 1, to: start)!
                    }
                    startDate = start 
                } else {
                    startDate = calendar.startOfDay(for: event.date)
                    endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
                }
                
                let _ = try eventKitService.createEvent(
                    title: event.title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: event.isAllDay,
                    calendar: targetCalendar,
                    location: event.location,
                    url: event.url,
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
        Task {
            if let ekEventId = event.ekEventId {
                // Try to find the event first
                // Actually EventKitService needs a delete method that takes ID or EKEvent
                // Let's assume we need to fetch it first or add a helper to service
                // For now, let's add a safe delete to EventKitService
                do {
                   try await eventKitService.deleteEvent(withId: ekEventId)
                   await MainActor.run {
                       events.removeAll { $0.id == event.id }
                       // also reload to be safe
                       loadEventsFromEventKit()
                   }
                } catch {
                    print("Error deleting event: \(error)")
                }
            } else {
                // Fallback for events without ID (should not happen for EK events)
                await MainActor.run {
                     events.removeAll { $0.id == event.id }
                }
            }
        }
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
            eventKitService.fetchCalendars() // 獲取日曆列表
            loadEventsFromEventKit()
        }
    }
    
    func requestCalendarAccess() {
        Task {
            let granted = await eventKitService.requestAccess()
            await MainActor.run {
                hasCalendarAccess = granted
                if granted {
                    eventKitService.fetchCalendars() // 獲取日曆列表
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
        
        // Filter visible calendars
        let visibleCalendars = availableCalendars.filter { isCalendarVisible($0) }
        
        // 如果 availableCalendars 為空（尚未加載），傳入 nil 以獲取所有（預設行為）
        // 如果已加載但 visibleCalendars 為空（用戶隱藏全部），傳入空陣列（不顯示任何事件）
        let calendarsToFetch = availableCalendars.isEmpty ? nil : visibleCalendars
        
        let ekEvents = eventKitService.fetchEvents(from: startOfMonth, to: endOfMonth, calendars: calendarsToFetch)
        
        // Convert EKEvent to CalendarEvent
        events = ekEvents.compactMap { ekEvent in
            guard let title = ekEvent.title,
                  let startDate = ekEvent.startDate,
                  let endDate = ekEvent.endDate else {
                return nil
            }
            
            return CalendarEvent(
                title: title,
                date: calendar.startOfDay(for: startDate),
                endDate: endDate,
                time: ekEvent.isAllDay ? nil : startDate,
                color: colorForCalendar(ekEvent.calendar),
                isAllDay: ekEvent.isAllDay,
                location: ekEvent.location,
                url: ekEvent.url,
                notes: ekEvent.notes,
                reminder: .none, // mapping reminder is complex, simplify for now
                calendarId: ekEvent.calendar.calendarIdentifier,
                ekEventId: ekEvent.eventIdentifier
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
        
        // 讀取設定：是否週一為第一天
        let startWeekOnMonday = UserDefaults.standard.bool(forKey: "startWeekOnMonday")
        let weekdayOffset = startWeekOnMonday ? 1 : 0
        
        let year = calendar.component(.year, from: currentMonth)
        let month = calendar.component(.month, from: currentMonth)
        
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return
        }
        
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // 調整週一開始 (weekday: 1=Sunday, 2=Monday, ..., 7=Saturday)
        if startWeekOnMonday {
            firstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
        }
        
        let daysInMonth = range.count
        
        // Previous month days
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
        let previousMonthRange = calendar.range(of: .day, in: .month, for: previousMonth)!
        let previousMonthDays = previousMonthRange.count
        
        for i in 0..<(firstWeekday - 1) {
            let day = previousMonthDays - (firstWeekday - 2) + i
            if let date = calendar.date(from: DateComponents(year: year, month: month - 1, day: day)) {
                let weekNum = calendar.component(.weekOfYear, from: date)
                let lunar = getLunarDay(date)
                result.append(CalendarDay(day: day, date: date, isCurrentMonth: false, isWeekend: isWeekend(date), weekNumber: weekNum, lunarDay: lunar))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                let weekNum = calendar.component(.weekOfYear, from: date)
                let lunar = getLunarDay(date)
                result.append(CalendarDay(day: day, date: date, isCurrentMonth: true, isWeekend: isWeekend(date), weekNumber: weekNum, lunarDay: lunar))
            }
        }
        
        // Next month days
        let remainingDays = 42 - result.count
        for day in 1...remainingDays {
            if let date = calendar.date(from: DateComponents(year: year, month: month + 1, day: day)) {
                let weekNum = calendar.component(.weekOfYear, from: date)
                let lunar = getLunarDay(date)
                result.append(CalendarDay(day: day, date: date, isCurrentMonth: false, isWeekend: isWeekend(date), weekNumber: weekNum, lunarDay: lunar))
            }
        }
        
        days = result
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    private func getLunarDay(_ date: Date) -> String {
        let chineseCalendar = Calendar(identifier: .chinese)
        let components = chineseCalendar.dateComponents([.day], from: date)
        
        guard let day = components.day else { return "" }
        
        let lunarDayTexts = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        
        return day > 0 && day <= lunarDayTexts.count ? lunarDayTexts[day - 1] : ""
    }
}
