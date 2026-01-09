import SwiftUI
import EventKit

// MARK: - Add Event View
struct AddEventView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    var editingEvent: CalendarEvent? = nil // 新增編輯屬性
    
    @AppStorage("defaultReminderTime") private var defaultReminderTime = 15
    
    @State private var title: String = ""
    @State private var selectedTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600) // Default +1h
    @State private var isAllDay: Bool = false
    @State private var location: String = ""
    @State private var locationCoordinate: LocationCoordinate? = nil
    @State private var urlString: String = ""
    @State private var notes: String = ""
    @State private var reminder: ReminderOption = .none
    @State private var selectedCalendarId: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 15)
            
            // Header
            HStack {
                Button("取消") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                
                Spacer()
                Text(editingEvent == nil ? "新增事件" : "編輯事件").font(.system(size: 14, weight: .semibold))
                Spacer()
                
                Button(editingEvent == nil ? "加入" : "儲存") { addEvent() }
                    .buttonStyle(.plain)
                    .foregroundColor(title.isEmpty ? .secondary : .accentColor)
                    .disabled(title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Title
                    InputGroup(label: "標題") {
                        TextField("事件名稱", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    }
                    
                    // Calendar Picker
                    InputGroup(label: "行事曆") {
                        Menu {
                            ForEach(viewModel.availableCalendars.filter { viewModel.isCalendarVisible($0) }, id: \.calendarIdentifier) { calendar in
                                Button(action: { selectedCalendarId = calendar.calendarIdentifier }) {
                                    HStack {
                                        if selectedCalendarId == calendar.calendarIdentifier {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(calendar.title)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if let calendar = selectedCalendar {
                                    Circle().fill(Color(cgColor: calendar.cgColor)).frame(width: 8, height: 8)
                                    Text(calendar.title).foregroundColor(.primary)
                                } else {
                                    Text("選擇行事曆").foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    // Date & Time
                    InputGroup(label: "時間") {
                        VStack(spacing: 12) {
                            // Date row (read-only for now as we select from calendar view)
                            HStack {
                                Image(systemName: "calendar").foregroundColor(.red)
                                Text(viewModel.selectedDateString)
                                Spacer()
                            }
                            
                            Toggle(isOn: $isAllDay) {
                                Text("全天")
                            }
                            .toggleStyle(.switch)
                            
                            if !isAllDay {
                                Divider()
                                HStack {
                                    Text("開始")
                                    Spacer()
                                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                                HStack {
                                    Text("結束")
                                    Spacer()
                                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    }
                    
                    // Location
                    InputGroup(label: "地點") {
                        LocationSearchField(
                            selectedLocation: Binding(
                                get: { location.isEmpty ? nil : location },
                                set: { location = $0 ?? "" }
                            ),
                            selectedCoordinate: $locationCoordinate
                        )
                    }
                    
                    // URL
                    InputGroup(label: "網址") {
                        HStack {
                            Image(systemName: "link").foregroundColor(.secondary)
                            TextField("URL", text: $urlString)
                                .textFieldStyle(.plain)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    }
                    
                    // Reminder
                    InputGroup(label: "提醒") {
                        Picker("", selection: $reminder) {
                            ForEach(ReminderOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    }
                    
                    // Notes
                    InputGroup(label: "備註") {
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(height: 80)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                            .scrollContentBackground(.hidden)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 360, height: 600)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            initializeDefaults()
        }
    }
    
    private var selectedCalendar: EKCalendar? {
        viewModel.availableCalendars.first { $0.calendarIdentifier == selectedCalendarId }
    }
    
    private func initializeDefaults() {
        if let event = editingEvent {
            // Pre-fill data from existing event
            title = event.title
            isAllDay = event.isAllDay
            selectedTime = event.time ?? event.date
            endTime = event.endDate
            location = event.location ?? ""
            locationCoordinate = event.locationCoordinate
            urlString = event.url?.absoluteString ?? ""
            notes = event.cleanNotes ?? ""
            reminder = event.reminder
            selectedCalendarId = event.calendarId ?? ""
            return
        }
        
        reminder = ReminderOption.fromMinutes(defaultReminderTime)
        
        let visibleCalendars = viewModel.availableCalendars.filter { viewModel.isCalendarVisible($0) }
        
        // Default to first available visible calendar
        if selectedCalendarId.isEmpty {
            // Try to find a good default (mutable) among visible ones
            if let defaultCal = visibleCalendars.first(where: { $0.isImmutable == false }) {
                selectedCalendarId = defaultCal.calendarIdentifier
            } else {
                selectedCalendarId = visibleCalendars.first?.calendarIdentifier ?? ""
            }
        }
        
        // Sync endTime with startTime initially
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = (calendar.component(.minute, from: now) / 15) * 15 // round to 15 min
        
        if let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) {
            selectedTime = start.addingTimeInterval(3600) // Start next hour roughly? 
            // Actually let's just keep current selectedTime logic but ensure endTime is >
            selectedTime = start
            endTime = start.addingTimeInterval(3600)
        }
    }
    
    private func addEvent() {
        // Construct dates
        let calendar = Calendar.current
        // Determine final start date with component
        var finalStartDate = editingEvent?.date ?? viewModel.selectedDate
        var finalEndDate = editingEvent?.date ?? viewModel.selectedDate
        
        if !isAllDay {
            // Combine selected date with time components
            finalStartDate = combineDateTime(date: finalStartDate, time: selectedTime)
            
            // For end date, if user picked a time that is "before" start time in clock terms (e.g. 11PM start, 1AM end),
            // we assume it means next day. But here we just combine.
            // A simpler approach: create both dates today. If end < start, add 1 day to end.
            var endCombined = combineDateTime(date: finalStartDate, time: endTime)
            if endCombined < finalStartDate {
                endCombined = calendar.date(byAdding: .day, value: 1, to: endCombined)!
            }
            finalEndDate = endCombined
        }
        
        let event = CalendarEvent(
            title: title,
            date: finalStartDate,
            endDate: finalEndDate,
            time: isAllDay ? nil : selectedTime,
            color: Color(cgColor: selectedCalendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)),
            isAllDay: isAllDay,
            location: location.isEmpty ? nil : location,
            locationCoordinate: locationCoordinate,
            url: URL(string: urlString),
            notes: notes.isEmpty ? nil : notes,
            reminder: reminder,
            calendarId: selectedCalendarId
        )
        
        if let oldEvent = editingEvent {
            viewModel.updateEvent(oldEvent: oldEvent, newEvent: event)
        } else {
            viewModel.addEvent(event)
        }
        
        isPresented = false
    }
    
    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
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
}

struct InputGroup<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            content
        }
    }
}
