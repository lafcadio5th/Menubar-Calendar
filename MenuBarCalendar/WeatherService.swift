import Foundation
import CoreLocation

class WeatherService {
    static let shared = WeatherService()
    
    private let locationManager = CLLocationManager()
    
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
        
        // Fetch weather from Open-Meteo
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code&timezone=auto"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }
        
        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
        
        return WeatherData(from: weatherResponse)
    }
}

// MARK: - Open-Meteo Response Models
struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather
    
    struct CurrentWeather: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
    }
}

enum WeatherError: LocalizedError {
    case noLocationPermission
    case locationUnavailable
    case invalidURL
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noLocationPermission:
            return "需要位置權限才能取得天氣資訊"
        case .locationUnavailable:
            return "無法取得目前位置"
        case .invalidURL:
            return "無效的 API 網址"
        case .networkError:
            return "網路連線錯誤"
        }
    }
}
