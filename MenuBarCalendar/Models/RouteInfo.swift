import Foundation
import MapKit

/// 路線資訊模型
/// 包含距離、時間、建議出發時間等資訊
struct RouteInfo {
    let distance: Double // 距離（公尺）
    let expectedTravelTime: TimeInterval // 預估時間（秒）
    let route: MKRoute
    let transportType: MKDirectionsTransportType
    
    // MARK: - Computed Properties
    
    /// 格式化的距離文字
    var distanceText: String {
        let kilometers = distance / 1000
        if kilometers < 1 {
            return String(format: "%.0f 公尺", distance)
        } else {
            return String(format: "%.1f 公里", kilometers)
        }
    }
    
    /// 格式化的通勤時間文字
    var travelTimeText: String {
        let minutes = Int(expectedTravelTime / 60)
        if minutes < 60 {
            return "約 \(minutes) 分鐘"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) 小時"
            } else {
                return "\(hours) 小時 \(remainingMinutes) 分鐘"
            }
        }
    }
    
    /// 計算建議出發時間
    /// - Parameters:
    ///   - eventTime: 事件開始時間
    ///   - bufferMinutes: 緩衝時間（分鐘），預設 5 分鐘
    /// - Returns: 建議出發時間
    func suggestedDepartureTime(for eventTime: Date, bufferMinutes: Int = 5) -> Date {
        let bufferTime: TimeInterval = TimeInterval(bufferMinutes * 60)
        return eventTime.addingTimeInterval(-expectedTravelTime - bufferTime)
    }
    
    /// 格式化的建議出發時間文字
    func suggestedDepartureTimeText(for eventTime: Date, bufferMinutes: Int = 5) -> String {
        let departureTime = suggestedDepartureTime(for: eventTime, bufferMinutes: bufferMinutes)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: departureTime)
    }
    
    /// 檢查是否該出發了
    /// - Parameters:
    ///   - eventTime: 事件開始時間
    ///   - bufferMinutes: 緩衝時間（分鐘）
    ///   - warningMinutes: 提前多少分鐘開始警告，預設 15 分鐘
    /// - Returns: (shouldDepart: 是否該出發, minutesUntilDeparture: 距離出發還有幾分鐘)
    func departureStatus(for eventTime: Date, bufferMinutes: Int = 5, warningMinutes: Int = 15) -> (shouldDepart: Bool, minutesUntilDeparture: Int) {
        let departureTime = suggestedDepartureTime(for: eventTime, bufferMinutes: bufferMinutes)
        let now = Date()
        let timeUntilDeparture = departureTime.timeIntervalSince(now)
        let minutesUntilDeparture = Int(timeUntilDeparture / 60)
        
        let shouldDepart = minutesUntilDeparture <= warningMinutes
        
        return (shouldDepart, minutesUntilDeparture)
    }
    
    /// 交通方式圖標
    var transportIcon: String {
        switch transportType {
        case .automobile:
            return "car.fill"
        case .walking:
            return "figure.walk"
        case .transit:
            return "tram.fill"
        default:
            return "car.fill"
        }
    }
    
    /// 交通方式名稱
    var transportName: String {
        switch transportType {
        case .automobile:
            return "開車"
        case .walking:
            return "步行"
        case .transit:
            return "大眾運輸"
        default:
            return "開車"
        }
    }
}

/// 多種交通方式的路線資訊
struct MultiRouteInfo {
    let driving: RouteInfo?
    let walking: RouteInfo?
    let transit: RouteInfo?
    
    /// 是否有任何路線資訊
    var hasAnyRoute: Bool {
        driving != nil || walking != nil || transit != nil
    }
    
    /// 最快的路線
    var fastestRoute: RouteInfo? {
        let routes = [driving, walking, transit].compactMap { $0 }
        return routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })
    }
    
    /// 推薦的路線（優先開車，其次步行，最後大眾運輸）
    var recommendedRoute: RouteInfo? {
        driving ?? walking ?? transit
    }
}
