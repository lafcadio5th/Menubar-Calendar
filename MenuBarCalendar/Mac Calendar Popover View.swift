
import SwiftUI

// MARK: - Calendar Popover View
struct CalendarPopoverView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showingAddEvent = false
    @AppStorage("startWeekOnMonday") private var startWeekOnMonday = false
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("showLunarCalendar") private var showLunarCalendar = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("showFestiveEffects") private var showFestiveEffects = true
    @AppStorage("demoFestival") var demoFestivalRaw: String = Festival.none.rawValue
    
    var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }
    
    private var currentFestival: Festival {
        if let demo = Festival(rawValue: demoFestivalRaw), demo != .none {
            return demo
        }
        return HolidayManager.shared.getCurrentFestival()
    }
    
    @State private var selectedEvent: CalendarEvent? = nil
    
    private var weekdays: [String] {
        if startWeekOnMonday {
            return ["一", "二", "三", "四", "五", "六", "日"]
        } else {
            return ["日", "一", "二", "三", "四", "五", "六"]
        }
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    // MARK: - Time of Day Logic
    private var currentTimeOfDay: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 19 || hour < 6 { return 2 } // Night
        if hour >= 17 || hour <= 7 { return 1 } // Sunset/Sunrise
        return 0 // Day
    }
    
    @AppStorage("showWeather") private var showWeather = false
    
    // MARK: - Dynamic Text Color
    private func weatherTextColor(for weatherCode: Int) -> Color {
        // If weather is disabled, always use primary color
        if !showWeather { return .primary }
        
        if currentTimeOfDay == 2 { return .white } // Night
        switch weatherCode {
        case 51...65, 80...82, 95...99: // Rain/Storm
            return .white
        default:
            if currentTimeOfDay == 1 { return .white } // Sunset
            return Color.primary
        }
    }
    
    private func weatherSecondaryTextColor(for weatherCode: Int) -> Color {
        // If weather is disabled, use secondary color
        if !showWeather { return .secondary }
        
        let baseColor = weatherTextColor(for: weatherCode)
        return baseColor == .white ? Color.white.opacity(0.85) : Color.secondary
    }
    
    // Helper for header color to avoid ViewBuilder syntax issues
    private var headerColor: Color {
        if let weather = viewModel.currentWeather {
            return weatherTextColor(for: weather.weatherCode).opacity(0.9)
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ========== Unified Header Box (Weather Bg + Info + Weekdays) ==========
            ZStack(alignment: .top) {
                // 1. Weather Background Layer
                if showWeather, let weather = viewModel.currentWeather {
                    WeatherAnimationView(weatherCode: weather.weatherCode, timeOfDay: currentTimeOfDay)
                        .frame(height: 110) // Bleed down behind grid
                        .frame(maxWidth: .infinity)

                }
                
                // 2. Content Layer (Info Row + Navigation Row + Weekday Row)
                VStack(spacing: 0) {
                    let weather = viewModel.currentWeather
                    // If weather contains data, use its code. Otherwise default to clear day (0) but showWeather flag handles color fallback
                    let weatherCode = weather?.weatherCode ?? 0
                    let textColor = weatherTextColor(for: weatherCode)
                    let secondaryColor = weatherSecondaryTextColor(for: weatherCode)
                    
                    // Row 1: Date & Weather (Height 32)
                    HStack(alignment: .center) {
                        Text(viewModel.currentMonthYear)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(textColor)
                        
                        Spacer()
                        
                        // Weather Info (Only show if enabled and available)
                        if showWeather, let weather = weather {
                            HStack(spacing: 6) {
                                Image(systemName: weather.symbolName)
                                    .font(.system(size: 14))
                                Text(weather.temperatureFormatted)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(weather.condition)
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryColor)
                            }
                            .foregroundColor(textColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    
                    // Row 2: Navigation (Height 28)
                    HStack(spacing: 0) {
                        Button(action: { viewModel.previousMonth() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textColor == .white ? .white : .blue)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button("今天") { viewModel.goToToday() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textColor == .white ? Color.white.opacity(0.9) : .blue)
                        
                        Spacer()
                        
                        Button(action: { viewModel.nextMonth() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textColor == .white ? .white : .blue)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { openSettingsWindow() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12))
                                .foregroundColor(secondaryColor)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    
                    // Row 3: Weekdays (Height 30)
                    HStack(spacing: 0) {
                        if showWeekNumbers {
                            Text("週")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(headerColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                            Divider().frame(height: 16).opacity(0.3)
                        }
                        ForEach(weekdays, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(headerColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                        }
                    }
                    .frame(height: 30)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10) // 指令：靠下對齊，並且距離紅線 10px
            }
            .frame(height: 110) // 指令：Header 高度鎖死
                Divider()
            
            // ========== Main Content (Grid + Events) ==========
            VStack(spacing: 0) {
                let totalRows = 6
                VStack(spacing: 4) {
                    ForEach(0..<totalRows, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            if showWeekNumbers {
                                let weekIndex = rowIndex * 7
                                if weekIndex < viewModel.days.count {
                                    Text("\(viewModel.days[weekIndex].weekNumber)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.85))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: showLunarCalendar ? 54 : 48)
                                } else {
                                    Spacer().frame(maxWidth: .infinity)
                                }
                                Divider().frame(height: showLunarCalendar ? 40 : 36)
                            }
                            
                            ForEach(0..<7) { colIndex in
                                let dayIndex = rowIndex * 7 + colIndex
                                if dayIndex < viewModel.days.count {
                                    let day = viewModel.days[dayIndex]
                                    DayCell(
                                        day: day,
                                        isSelected: viewModel.isSelected(day),
                                        isToday: viewModel.isToday(day),
                                        hasEvents: viewModel.hasEvents(on: day.date),
                                        showLunar: showLunarCalendar
                                    )
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        viewModel.selectDate(day.date)
                                    }
                                } else {
                                    Spacer().frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
            Divider()
            
            // Event List
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(viewModel.selectedDateString)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button(action: { showingAddEvent = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                if !viewModel.hasCalendarAccess {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                        Text("需要日曆存取權限").font(.system(size: 13, weight: .semibold))
                        Text("授權後即可查看與新增事件").font(.system(size: 11)).foregroundColor(.secondary)
                        Button("授權存取") { viewModel.requestCalendarAccess() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.selectedDateEvents.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("沒有事件").font(.system(size: 14)).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else {
                                ForEach(viewModel.selectedDateEvents) { event in
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(event.color)
                                            .frame(width: 4, height: 40)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(1)
                                            Text(event.timeString)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.spring()) { selectedEvent = event }
                                    }
                                }
                            }
                            
                            if !viewModel.todoistTasks.isEmpty {
                                Divider().padding(.vertical, 8)
                                HStack {
                                    Image(systemName: "checklist").foregroundColor(Color(red: 228/255, green: 67/255, blue: 50/255))
                                    Text("Todoist").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.bottom, 4)
                                ForEach(viewModel.todoistTasks) { task in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "circle").font(.system(size: 14)).foregroundColor(.secondary).padding(.top, 3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.content).font(.system(size: 14)).lineLimit(2)
                                            if let duestring = task.due?.string {
                                                Text(duestring).font(.system(size: 11)).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let url = URL(string: task.url) { NSWorkspace.shared.open(url) }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            .zIndex(1)
        }
        .frame(width: 340, height: 650)
        .zIndex(1)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(appTheme.colorScheme)
        .overlay(
            ZStack {
                if showFestiveEffects && currentFestival != .none {
                    FestivalDecorationView(festival: currentFestival)
                }
                
                if let event = selectedEvent {
                    Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { withAnimation { selectedEvent = nil } }
                    VStack {
                        Spacer()
                        
                        // 使用不同的視圖根據是否有地點
                        if event.locationCoordinate != nil {
                            EventLocationDetailViewWrapper(
                                event: event,
                                onClose: { withAnimation { selectedEvent = nil } },
                                onDelete: { withAnimation { viewModel.deleteEvent(event); selectedEvent = nil } }
                            )
                            .transition(.move(edge: .bottom))
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
                        } else {
                            EventDetailView(
                                event: event,
                                onClose: { withAnimation { selectedEvent = nil } },
                                onDelete: { withAnimation { viewModel.deleteEvent(event); selectedEvent = nil } }
                            )
                            .frame(height: 480)
                            .transition(.move(edge: .bottom))
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
                        }
                    }
                }
            }
        )
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(viewModel: viewModel, isPresented: $showingAddEvent)
                .preferredColorScheme(appTheme.colorScheme)
        }
    }
    
    private func openSettingsWindow() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let showLunar: Bool
    
    @State private var isHovering = false
    @AppStorage("eventIndicatorColor") private var eventIndicatorColorHex = "#007AFF"
    
    var body: some View {
        VStack(spacing: showLunar ? 3 : 2) {
            ZStack {
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 34, height: 34)
                } else if isToday {
                    Circle().stroke(Color.blue, lineWidth: 2).frame(width: 34, height: 34)
                } else if isHovering {
                    Circle().fill(Color.secondary.opacity(0.1)).frame(width: 34, height: 34)
                }
                
                VStack(spacing: 2) {
                    Text("\(day.day)")
                        .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                        .foregroundColor(textColor)
                    
                    if showLunar && !day.lunarDay.isEmpty {
                        Text(day.lunarDay)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(lunarTextColor)
                    }
                }
            }
            .frame(width: 38, height: 38)
        }
        .frame(height: showLunar ? 54 : 48)
        .contentShape(Rectangle())
        .onHover { hovering in isHovering = hovering }
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if hasEvents { return Color(hex: eventIndicatorColorHex) ?? .blue }
        if !day.isCurrentMonth { return .secondary.opacity(0.4) }
        else if day.isWeekend { return .secondary }
        return .primary
    }
    
    private var lunarTextColor: Color {
        if isSelected { return .white.opacity(0.85) }
        else if !day.isCurrentMonth { return .secondary.opacity(0.3) }
        else { return .secondary.opacity(0.75) }
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Event Location Detail View Wrapper
struct EventLocationDetailViewWrapper: View {
    let event: CalendarEvent
    var onClose: () -> Void
    var onDelete: () -> Void
    
    @StateObject private var routeViewModel = RouteViewModel()
    
    var body: some View {
        EventLocationDetailView(
            event: event,
            routeInfo: routeViewModel.routeInfo,
            onClose: onClose,
            onDelete: onDelete
        )
        .onAppear {
            // Calculate route if event has location
            if let coordinate = event.locationCoordinate {
                Task {
                    await routeViewModel.calculateRoute(to: coordinate)
                }
            }
        }
    }
}
