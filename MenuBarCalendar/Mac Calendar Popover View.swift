import SwiftUI
import AppKit

struct CalendarPopoverView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @AppStorage("showLunarCalendar") private var showLunarCalendar = true
    @AppStorage("isPinnedToDesktop") private var isPinnedToDesktop = false
    @AppStorage("showWeather") private var showWeather = true
    @AppStorage("weatherStyle") private var weatherStyleRaw = WeatherStyle.realistic.rawValue
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("showWeekNumbers") private var showWeekNumbers = true

    var currentTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .system }
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    @ObservedObject var dragState: DesktopWindowController.DragState
    
    @State private var showingAddEvent = false
    @State private var selectedEvent: CalendarEvent?
    @State private var contentHeight: CGFloat = 0
    @State private var currentPopoverWidth: CGFloat = 340
    
    // Debug / Preview Settings (Synced with SettingsView)
    @AppStorage("debugWeatherCode") private var debugWeatherCode: Int = -1
    @AppStorage("debugTimeOfDay") private var debugTimeOfDay: Int = 0
    
    @State private var weatherVariant: Int = Int.random(in: 0...3) // Randomize Variant (0..3)
    let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var currentTimeOfDay: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 17 {
            return 0 // Day
        } else if hour >= 17 && hour < 19 {
            return 1 // Sunset
        } else {
            return 2 // Night
        }
    }

    private var headerColor: Color {
        return showWeather ? .white : .primary
    }

    private var heightReader: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: HeightPreferenceKey.self, value: geometry.size.height)
        }
    }
    
    var body: some View {
        // CONTENT LAYER (With ClipShape)
        ZStack(alignment: .top) {
            // 1. 常規日曆視圖
            ZStack(alignment: .top) {
                skyBackground
                VStack(spacing: 0) {
                    premiumHeader
                    calendarGrid
                    if selectedEvent == nil {
                        eventListArea
                    }
                }
            }
            // 2. 事件詳情視圖
            if let event = selectedEvent {
                Color.black.opacity(0.01).ignoresSafeArea().onTapGesture { 
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentPopoverWidth = 340
                        selectedEvent = nil 
                    }
                }
                
                VStack {
                    // Spacer() removed to prevent pushing content down
                    if let location = event.location, !location.isEmpty {
                        EventLocationDetailViewWrapper(
                            viewModel: viewModel,
                            event: event,
                            popoverWidth: $currentPopoverWidth,
                            onClose: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    currentPopoverWidth = 340 // Reset width
                                    selectedEvent = nil
                                }
                            },
                            onDelete: {
                                withAnimation {
                                    viewModel.deleteEvent(event)
                                    currentPopoverWidth = 340
                                    selectedEvent = nil
                                }
                            }
                        )
                    } else {
                        EventDetailView(
                            viewModel: viewModel,
                            event: event,
                            onClose: { selectedEvent = nil }, // Standard detail doesn't change width?
                            onDelete: { withAnimation { viewModel.deleteEvent(event); selectedEvent = nil } }
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
                .background(colorScheme == .dark ? Color.black : Color.white)
                .zIndex(2)
            }
        }
        .frame(width: currentPopoverWidth)
        .frame(height: (selectedEvent != nil) ? nil : 650, alignment: .top)
        .background(isPinnedToDesktop ? Color.clear : (colorScheme == .dark ? Color.black : Color.white))
        .clipShape(RoundedRectangle(cornerRadius: isPinnedToDesktop ? 12 : 10)) // 剪裁內容
        // SHADOW LAYER (Applied to Background, Unclipped)
        .background(
            UnclippedShadow(
                isActive: isPinnedToDesktop,
                colorScheme: colorScheme
            )
        )
        .padding(isPinnedToDesktop ? 40 : 0) // 40px for shadow breathing room
        .preferredColorScheme(colorScheme)
        // Ensure we capture the height INCLUDING the padding
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self, perform: handleHeightChange)
        .onChange(of: currentPopoverWidth) { _ in notifySizeUpdate() }
        .onChange(of: contentHeight) { _ in notifySizeUpdate() }
        .onChange(of: isPinnedToDesktop) { _ in notifySizeUpdate() }
        .sheet(isPresented: $showingAddEvent) { AddEventView(viewModel: viewModel, isPresented: $showingAddEvent) }
    }
    
    // Helper View for Shadow
    struct UnclippedShadow: View {
        let isActive: Bool
        let colorScheme: ColorScheme?
        var body: some View {
            if isActive {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.black : Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 1.5)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
            }
        }
    }
    // MARK: - Subviews

    private var skyBackground: some View {
        Group {
            if showWeather && !dragState.isDragging {
                let weather = viewModel.currentWeather
                WeatherAnimationView(
                    weatherCode: debugWeatherCode != -1 ? debugWeatherCode : (weather?.weatherCode ?? 0),
                    timeOfDay: debugWeatherCode != -1 ? debugTimeOfDay : currentTimeOfDay,
                    style: WeatherStyle(rawValue: weatherStyleRaw) ?? .realistic,
                    variant: weatherVariant
                )
                .frame(height: isPinnedToDesktop ? (selectedEvent != nil ? CGFloat(110) : CGFloat(400)) : CGFloat(120))
            } else {
                (colorScheme == .dark ? Color.black : Color.white)
                    .frame(height: isPinnedToDesktop ? (selectedEvent != nil ? CGFloat(110) : CGFloat(400)) : CGFloat(120))
            }
        }
        .frame(maxWidth: .infinity)
        .zIndex(0)
    }

    private var premiumHeader: some View {
        VStack(spacing: 0) {
            // Split Quadrant Layout
            // Top Row
            HStack(alignment: .top) {
                // Top-Left: Month Title
                Text(viewModel.currentMonthNameShort)
                    .font(.system(size: 28, weight: .bold)) // Larger font for simplified title
                    .foregroundColor(headerColor)
                
                Spacer()
                
                // Top-Right: Weather Info (Info Up)
                if let weather = viewModel.currentWeather {
                    HStack(spacing: 6) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 20))
                        Text(weather.temperatureFormatted)
                            .font(.system(size: 20, weight: .bold)) // Slightly larger
                    }
                    .foregroundColor(headerColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Bottom Row
            HStack(alignment: .bottom) {
                // Bottom-Left: Navigation
                HStack(spacing: 12) {
                    Button(action: { viewModel.previousMonth() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold)) // Slightly larger
                            .foregroundColor(headerColor) 
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.goToToday() }) { 
                        Text("今天")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(headerColor) 
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.nextMonth() }) { 
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(headerColor) 
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Bottom-Right: Utility Buttons (Function Down)
                HStack(spacing: 16) {
                    Button(action: { isPinnedToDesktop.toggle(); NotificationCenter.default.post(name: Notification.Name("ToggleDesktopMode"), object: isPinnedToDesktop) }) { 
                        Image(systemName: isPinnedToDesktop ? "pin.fill" : "pin")
                            .font(.system(size: 15)) // Moderate size
                            .foregroundColor(headerColor.opacity(0.8)) 
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { openSettingsWindow() }) { 
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundColor(headerColor.opacity(0.8)) 
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 120) // Keep fixed height for header area
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showWeekNumbers { 
                    Text("週").font(.system(size: 11, weight: .bold)).foregroundColor(isPinnedToDesktop ? headerColor.opacity(0.4) : .secondary.opacity(0.4)).frame(width: 25)
                    Divider().frame(height: 12).opacity(0.2).padding(.horizontal, 4) 
                }
                ForEach(weekdays, id: \.self) { day in 
                    Text(day).font(.system(size: 12, weight: .bold)).foregroundColor(isPinnedToDesktop ? headerColor.opacity(0.7) : .secondary.opacity(0.7)).frame(maxWidth: .infinity) 
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: showWeekNumbers ? 8 : 7), spacing: 0) {
                // 強制顯示 5 週 (35天)，解決佈局過高的問題
                ForEach(0..<min(viewModel.days.count, 35), id: \.self) { index in
                    if showWeekNumbers && index % 7 == 0 {
                        let day = viewModel.days[index]
                        HStack(spacing: 0) {
                            Text("\(day.weekNumber)").font(.system(size: 10, weight: .medium)).foregroundColor(isPinnedToDesktop ? headerColor.opacity(0.5) : .secondary.opacity(0.5)).frame(width: 25)
                            Divider().frame(height: showLunarCalendar ? 36 : 32).opacity(0.2).padding(.horizontal, 4)
                        }
                    }
                    let day = viewModel.days[index]
                    DayCell(day: day, isSelected: viewModel.isSelected(day), isToday: viewModel.isToday(day), hasEvents: viewModel.hasEvents(on: day.date), showLunar: showLunarCalendar, isDesktopMode: isPinnedToDesktop)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { viewModel.selectDate(day.date) }
                }
            }.padding(.horizontal, 8)
        }
        .background(isPinnedToDesktop ? Color.clear : (colorScheme == .dark ? Color.black : Color.white))
        .frame(height: isPinnedToDesktop ? 245 : 240) // 5週高度調整
    }

    private var eventListArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack {
                Text(viewModel.selectedDateString).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                Spacer()
                Button(action: { showingAddEvent = true }) { Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(.blue) }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.selectedDateEvents.isEmpty && viewModel.todoistTasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.25)).padding(.top, 30)
                            Text("沒有事件或待辦").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary.opacity(0.7))
                        }.frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.selectedDateEvents) { event in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 4, height: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title).font(.system(size: 14, weight: .semibold)).lineLimit(1).foregroundColor(.primary)
                                    Text(event.timeString).font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04))).onTapGesture { withAnimation(.spring()) { selectedEvent = event } }
                        }
                        
                        if !viewModel.todoistTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("待辦事項").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.top, 10).padding(.bottom, 2)
                                ForEach(viewModel.todoistTasks) { task in
                                    HStack(spacing: 12) {
                                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : priorityColor(task.priority)).font(.system(size: 18))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.content).font(.system(size: 14, weight: .medium)).strikethrough(task.isCompleted).foregroundColor(task.isCompleted ? .secondary : .primary).lineLimit(2)
                                        }
                                        Spacer()
                                    }.padding(.horizontal, 12).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .frame(maxHeight: .infinity)
    }


    // MARK: - Handlers & Helpers

    private func notifySizeUpdate() {
        guard isPinnedToDesktop else { return }
        // Guard against invalid sizes (e.g. during view transitions)
        guard contentHeight > 50, currentPopoverWidth > 50 else { return }
        
        let totalWidth = currentPopoverWidth + 80
        let sizeDict: [String: CGFloat] = ["width": totalWidth, "height": contentHeight]
        NotificationCenter.default.post(name: Notification.Name("UpdateDesktopWindowSize"), object: sizeDict)
    }

    private func handleHeightChange(_ height: CGFloat) { contentHeight = height }
    
    private func openSettingsWindow() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 4: return .red
        case 3: return .orange
        case 2: return .blue
        default: return .secondary.opacity(0.8)
        }
    }
}

struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let showLunar: Bool
    let isDesktopMode: Bool
    @State private var isHovering = false
    @AppStorage("eventIndicatorColor") private var eventIndicatorColorHex = "#007AFF"
    var body: some View {
        VStack(spacing: showLunar ? 3 : 2) {
            ZStack {
                if isSelected { Circle().fill(Color.blue).frame(width: 32, height: 32) }
                else if isToday { Circle().stroke(Color.blue, lineWidth: 2).frame(width: 32, height: 32) }
                else if isHovering { Circle().fill(isDesktopMode ? Color.white.opacity(0.1) : Color.secondary.opacity(0.1)).frame(width: 32, height: 32) }
                VStack(spacing: 2) {
                    Text("\(day.day)").font(.system(size: 14, weight: isToday || isSelected ? .bold : .medium)).foregroundColor(isSelected ? .white : (hasEvents ? Color(hex: eventIndicatorColorHex) ?? .blue : (isDesktopMode ? (day.isCurrentMonth ? .white : .white.opacity(0.4)) : (day.isCurrentMonth ? .primary : .secondary.opacity(0.4)))))
                    if showLunar && !day.lunarDay.isEmpty { Text(day.lunarDay).font(.system(size: 9, weight: .medium)).foregroundColor(isSelected ? .white.opacity(0.8) : (isDesktopMode ? .white.opacity(0.6) : .secondary.opacity(0.7))) }
                }
            }.frame(width: 34, height: 34)
        }.frame(height: showLunar ? 50 : 44).contentShape(Rectangle()).onHover { isHovering = $0 }
    }
}

struct EventLocationDetailViewWrapper: View {
    @ObservedObject var viewModel: CalendarViewModel
    let event: CalendarEvent
    @Binding var popoverWidth: CGFloat
    var onClose: () -> Void
    var onDelete: () -> Void
    @StateObject private var routeViewModel = RouteViewModel()
    var body: some View {
        EventLocationDetailView(viewModel: viewModel, event: event, routeInfo: routeViewModel.routeInfo, onClose: onClose, onDelete: onDelete, popoverWidth: $popoverWidth)
            .onAppear { if let coord = event.locationCoordinate { Task { await routeViewModel.calculateRoute(to: coord) } } }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

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
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
