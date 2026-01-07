
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
        // 優先使用 demo 設定
        if let demo = Festival(rawValue: demoFestivalRaw), demo != .none {
            return demo
        }
        return HolidayManager.shared.getCurrentFestival()
    }
    
    @State private var selectedEvent: CalendarEvent? = nil // New state for details
    
    private var weekdays: [String] {
        if startWeekOnMonday {
            return ["一", "二", "三", "四", "五", "六", "日"]
        } else {
            return ["日", "一", "二", "三", "四", "五", "六"]
        }
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 15)
            
            // ========== 月份導航 ==========
            HStack(spacing: 0) {
                Button(action: { viewModel.previousMonth() }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(viewModel.currentMonthYear)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Button("今天") {
                        viewModel.goToToday()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: { viewModel.nextMonth() }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
                
                // 設定按鈕
                Button(action: { openSettingsWindow() }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            
            // 主要內容容器 - 統一網格佈局
            VStack(spacing: 0) {
                
                // 1. 統一標題列 (週 + 日 一 二 ...)
                HStack(spacing: 0) {
                    // 週數標題
                    if showWeekNumbers {
                        Text("週")
                            .font(.system(size: 11, weight: .bold)) // 修改：字體對齊日期標題
                            .foregroundColor(.secondary.opacity(0.8))
                            .frame(maxWidth: .infinity) // 關鍵：均分寬度
                            .frame(height: 30) // 高度與日期標題一致
                        
                        Divider()
                            .frame(height: 16) // 分隔線高度微調
                    }
                    
                    // 星期標題
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity) // 關鍵：均分寬度
                            .frame(height: 30)
                    }
                }
                
                Divider()
                
                // 2. 統一內容網格 (週數值 + 日期值)
                // 這裡我們需要手動構建行與列，以確保週數與日期在同一行絕對對齊
                
                // 計算總行數 (通常是 6 行)
                let totalRows = 6
                
                VStack(spacing: 4) { // 行間距
                    ForEach(0..<totalRows, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            
                            // 週數列 (每行的第一欄)
                            if showWeekNumbers {
                                let weekIndex = rowIndex * 7
                                if weekIndex < viewModel.days.count {
                                    Text("\(viewModel.days[weekIndex].weekNumber)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.85))
                                        .frame(maxWidth: .infinity) // 關鍵：均分寬度，與標題 "週" 對齊
                                        .frame(height: showLunarCalendar ? 54 : 48)
                                } else {
                                    Spacer().frame(maxWidth: .infinity)
                                }
                                
                                Divider()
                                    .frame(height: showLunarCalendar ? 40 : 36)
                            }
                            
                            // 日期列 (每行的後7欄)
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
                                    .frame(maxWidth: .infinity) // 關鍵：均分寬度
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
            
            // ========== 事件列表 ==========
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
                    // Calendar Permission Request
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                        
                        Text("需要日曆存取權限")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text("授權後即可查看與新增事件")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("授權存取") {
                            viewModel.requestCalendarAccess()
                        }
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
                                    Text("沒有事件")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
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
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.primary.opacity(0.04))
                                    )
                                    .contentShape(Rectangle()) // Ensure tap area
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            selectedEvent = event
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
            }
            .frame(height: 180)
        }
        .frame(width: 340, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(appTheme.colorScheme)
        .overlay(
            ZStack {
                // Festive Effects Overlay
                if showFestiveEffects && currentFestival != .none {
                    FestivalDecorationView(festival: currentFestival)
                }
                
                if let event = selectedEvent {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedEvent = nil
                            }
                        }
                    
                    VStack {
                        Spacer()
                        EventDetailView(
                            event: event,
                            onClose: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedEvent = nil
                                }
                            },
                            onDelete: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    viewModel.deleteEvent(event)
                                    selectedEvent = nil
                                }
                            }
                        )
                        .frame(height: 480)
                        .transition(.move(edge: .bottom))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
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
                // 背景圓形
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 34, height: 34)
                } else if isHovering {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 34, height: 34)
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
            
            // 移除事件標記橫條，改為文字顏色區分
            // 為了保持佈局高度一致，使用透明 Spacer 佔位（或直接讓 VStack 自動置中）
            // 由於外層 Grid 限制了高度，VStack 會垂直置中，這裡不需要額外的 Spacer
        }
        .frame(height: showLunar ? 54 : 48)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        }
        
        if hasEvents {
            return Color(hex: eventIndicatorColorHex) ?? .blue
        }
        
        if !day.isCurrentMonth {
            return .secondary.opacity(0.4)
        } else if day.isWeekend {
            return .secondary
        }
        return .primary
    }
    
    private var lunarTextColor: Color {
        if isSelected {
            return .white.opacity(0.85)
        } else if !day.isCurrentMonth {
            return .secondary.opacity(0.3)
        } else {
            return .secondary.opacity(0.75)
        }
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
