import Foundation
import EventKit

enum Festival: String, CaseIterable, Identifiable {
    case none
    case lunarNewYear = "lunarNewYear"
    case christmas = "christmas"
    case newYear = "newYear"
    case midAutumn = "midAutumn"
    case dragonBoat = "dragonBoat"
    case valentines = "valentines"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "自動 (預設)"
        case .lunarNewYear: return "農曆新年"
        case .christmas: return "聖誕節"
        case .newYear: return "元旦"
        case .midAutumn: return "中秋節"
        case .dragonBoat: return "端午節"
        case .valentines: return "情人節"
        }
    }
    
    var emojis: [String] {
        switch self {
        case .none: return []
        case .lunarNewYear: return ["🧧", "🏮", "✨"]
        case .christmas: return ["❄️", "🎄", "🎅"]
        case .newYear: return ["🎉", "🥂", "🎆"]
        case .midAutumn: return ["🥮", "🌕", "🍵"]
        case .dragonBoat: return ["🎋", "🚣", "🌊"]
        case .valentines: return ["❤️", "🌹", "🍫"]
        }
    }
}

class HolidayManager {
    static let shared = HolidayManager()
    
    private let lunarCalendar = Calendar(identifier: .chinese)
    private let gregorianCalendar = Calendar(identifier: .gregorian)
    
    func getCurrentFestival(date: Date = Date()) -> Festival {
        let components = gregorianCalendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return .none }
        
        // 1. Gregorian Festivals
        if month == 12 && (24...26).contains(day) {
            return .christmas
        }
        if month == 1 && day == 1 {
            return .newYear
        }
        if month == 2 && day == 14 {
            return .valentines
        }
        
        // 2. Lunar Festivals
        let lunarComponents = lunarCalendar.dateComponents([.month, .day], from: date)
        guard let lMonth = lunarComponents.month, let lDay = lunarComponents.day else { return .none }
        
        // Lunar New Year (Spring Festival): Month 1, Day 1-3
        if lMonth == 1 && (1...3).contains(lDay) {
            return .lunarNewYear
        }
        
        // Dragon Boat Festival: Month 5, Day 5
        if lMonth == 5 && lDay == 5 {
            return .dragonBoat
        }
        
        // Mid-Autumn Festival: Month 8, Day 15
        if lMonth == 8 && lDay == 15 {
            return .midAutumn
        }
        
        // Exclude Lunar New Year Eve for now as it handles 'end of year' logic which is tricky with leap months sometimes, 
        // but typically Month 12 (or last month) Day 29/30. 
        // Let's stick to the main ones.
        
        return .none
    }
}
