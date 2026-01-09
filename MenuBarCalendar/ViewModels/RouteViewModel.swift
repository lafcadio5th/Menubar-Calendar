import Foundation
import MapKit
import Combine

/// 路線計算 ViewModel
/// 負責計算和管理事件的路線資訊
@MainActor
class RouteViewModel: ObservableObject {
    @Published var routeInfo: MultiRouteInfo?
    @Published var isCalculating = false
    @Published var error: Error?
    
    private let mapService = MapService.shared
    private let locationService = LocationService.shared
    
    // 快取：避免重複計算相同的路線
    private var routeCache: [String: MultiRouteInfo] = [:]
    
    // MARK: - Public Methods
    
    /// 計算到目的地的路線
    /// - Parameter destination: 目的地座標
    func calculateRoute(to destination: LocationCoordinate) async {
        // 檢查是否有當前位置
        guard let currentLocation = locationService.currentLocation else {
            // 如果沒有位置，嘗試請求
            locationService.requestLocation()
            error = NSError(domain: "RouteViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "正在取得您的位置..."
            ])
            return
        }
        
        // 檢查快取
        let cacheKey = "\(currentLocation.coordinate.latitude),\(currentLocation.coordinate.longitude)-\(destination.latitude),\(destination.longitude)"
        if let cached = routeCache[cacheKey] {
            routeInfo = cached
            return
        }
        
        isCalculating = true
        error = nil
        
        do {
            let routes = try await mapService.calculateAllRoutes(
                from: currentLocation.coordinate,
                to: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
            )
            
            // 轉換為 RouteInfo
            let drivingInfo = routes.driving.map { RouteInfo(
                distance: $0.distance,
                expectedTravelTime: $0.expectedTravelTime,
                route: $0,
                transportType: .automobile
            )}
            
            let walkingInfo = routes.walking.map { RouteInfo(
                distance: $0.distance,
                expectedTravelTime: $0.expectedTravelTime,
                route: $0,
                transportType: .walking
            )}
            
            let transitInfo = routes.transit.map { RouteInfo(
                distance: $0.distance,
                expectedTravelTime: $0.expectedTravelTime,
                route: $0,
                transportType: .transit
            )}
            
            let multiRoute = MultiRouteInfo(
                driving: drivingInfo,
                walking: walkingInfo,
                transit: transitInfo
            )
            
            // 儲存到快取
            routeCache[cacheKey] = multiRoute
            routeInfo = multiRoute
            isCalculating = false
            
        } catch {
            self.error = error
            isCalculating = false
            print("Route calculation error: \(error.localizedDescription)")
        }
    }
    
    /// 清除路線資訊
    func clearRoute() {
        routeInfo = nil
        error = nil
    }
    
    /// 清除快取
    func clearCache() {
        routeCache.removeAll()
    }
}

// MARK: - Helper Extension
extension CLLocationCoordinate2D {
    init(from coordinate: LocationCoordinate) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
