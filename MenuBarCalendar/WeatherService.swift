import Foundation
import CoreLocation
import WeatherKit

class WeatherService {
    static let shared = WeatherService()
    
    private let locationManager = CLLocationManager()
    private let weatherKit = WeatherKit.WeatherService.shared
    
    private init() {
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    var hasLocationPermission: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedAlways || status == .authorized
    }
    
    func fetchWeather() async throws -> WeatherData {
        // Get current location
        guard hasLocationPermission else {
            throw WeatherError.noLocationPermission
        }
        
        guard let location = locationManager.location else {
            throw WeatherError.locationUnavailable
        }
        
        // Fetch weather from WeatherKit
        let weather = try await weatherKit.weather(for: location)
        
        return WeatherData(from: weather.currentWeather)
    }
}

enum WeatherError: LocalizedError {
    case noLocationPermission
    case locationUnavailable
    case weatherKitError
    
    var errorDescription: String? {
        switch self {
        case .noLocationPermission:
            return "需要位置權限才能取得天氣資訊"
        case .locationUnavailable:
            return "無法取得目前位置"
        case .weatherKitError:
            return "無法取得天氣資料"
        }
    }
}
