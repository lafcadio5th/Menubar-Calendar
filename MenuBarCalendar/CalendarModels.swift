import SwiftUI

// MARK: - Calendar Day Model
struct CalendarDay: Identifiable {
    let id = UUID()
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
    let isWeekend: Bool
    let weekNumber: Int
    let lunarDay: String
}

// MARK: - Reminder Option
enum ReminderOption: String, CaseIterable, Codable {
    case none = "none"
    case atTime = "atTime"
    case fiveMinutes = "5min"
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    case oneHour = "1hour"
    case oneDay = "1day"
    
    var displayName: String {
        switch self {
        case .none: return "無"
        case .atTime: return "事件發生時"
        case .fiveMinutes: return "5 分鐘前"
        case .fifteenMinutes: return "15 分鐘前"
        case .thirtyMinutes: return "30 分鐘前"
        case .oneHour: return "1 小時前"
        case .oneDay: return "1 天前"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .none: return nil
        case .atTime: return 0
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .oneDay: return 24 * 60 * 60
        }
    }
    
    static func fromMinutes(_ minutes: Int) -> ReminderOption {
        switch minutes {
        case 0: return .none
        case 5: return .fiveMinutes
        case 10: return .fiveMinutes  // 使用最接近的選項
        case 15: return .fifteenMinutes
        case 30: return .thirtyMinutes
        case 60: return .oneHour
        case 1440: return .oneDay
        default: return .none
        }
    }
}

// MARK: - Calendar Event Model
struct CalendarEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date // Start Date
    var endDate: Date // New: End Date
    var time: Date?
    var colorHex: String
    var isAllDay: Bool
    var location: String? // New
    var url: URL? // New
    var notes: String?
    var reminder: ReminderOption
    var calendarId: String? // New: To identify which calendar it belongs to
    var ekEventId: String? // New: To link back to EventKit
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    var timeString: String {
        if isAllDay {
            return "全天"
        }
        guard let time = time else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Calculate end time string if available and not same as start
        if !isAllDay {
           let endFormatter = DateFormatter()
           endFormatter.dateFormat = "HH:mm"
           let endString = endFormatter.string(from: endDate)
           return "\(formatter.string(from: time)) - \(endString)"
        }
        
        return formatter.string(from: time)
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        time: Date?,
        color: Color,
        isAllDay: Bool,
        location: String? = nil,
        url: URL? = nil,
        notes: String?,
        reminder: ReminderOption,
        calendarId: String? = nil,
        ekEventId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        // If endDate is not provided, default to date + 1 hour or same day for all day
        if let end = endDate {
            self.endDate = end
        } else {
             // Default logic: 1 hour duration
             self.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        }
        self.time = time
        self.colorHex = color.toHex() ?? "#007AFF"
        self.isAllDay = isAllDay
        self.location = location
        self.url = url
        self.notes = notes
        self.reminder = reminder
        self.calendarId = calendarId
        self.ekEventId = ekEventId
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else { return nil }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
    
    static let eventColors: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .teal, .cyan, .blue, .indigo, .purple, .pink
    ]
    
    static func randomEventColor() -> Color {
        eventColors.randomElement() ?? .blue
    }
}
