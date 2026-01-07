
import SwiftUI

// MARK: - Calendar Popover View
struct CalendarPopoverView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showingAddEvent = false
    
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 30)
            
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
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            
            Divider()
            
            // ========== 星期標題 ==========
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // ========== 日曆網格 ==========
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.days, id: \.id) { day in
                    DayCell(
                        day: day,
                        isSelected: viewModel.isSelected(day),
                        isToday: viewModel.isToday(day),
                        hasEvents: viewModel.hasEvents(on: day.date)
                    )
                    .onTapGesture {
                        viewModel.selectDate(day.date)
                    }
                }
            }
            .padding(.horizontal, 12)
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
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(viewModel: viewModel, isPresented: $showingAddEvent)
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .stroke(Color.blue, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
                
                Text("\(day.day)")
                    .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
            }
            .frame(width: 36, height: 36)
            
            Circle()
                .fill(hasEvents && !isSelected ? Color.blue : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if !day.isCurrentMonth {
            return .secondary.opacity(0.4)
        } else if day.isWeekend {
            return .secondary
        }
        return .primary
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
