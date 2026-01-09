import Foundation
import WeatherKit

struct WeatherData {
    let temperature: Double // Celsius
    let condition: String
    let symbolName: String
    let feelsLike: Double
    let humidity: Double
    let weatherCode: Int // For animation
    
    var temperatureFormatted: String {
        String(format: "%.0f°", temperature)
    }
    
    var humidityFormatted: String {
        String(format: "%.0f%%", humidity * 100)
    }
}

extension WeatherData {
    // WeatherKit initializer
    init(from weather: CurrentWeather) {
        self.temperature = weather.temperature.value
        self.feelsLike = weather.apparentTemperature.value
        self.humidity = weather.humidity
        
        // Map WeatherKit condition to WMO code for animation compatibility
        self.weatherCode = Self.weatherKitConditionToWMOCode(weather.condition)
        
        let weatherInfo = Self.weatherCodeToInfo(self.weatherCode)
        self.condition = weatherInfo.condition
        self.symbolName = weatherInfo.symbol
    }
    
    // Convert WeatherKit condition to WMO weather code
    private static func weatherKitConditionToWMOCode(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear: return 0
        case .mostlyClear: return 1
        case .partlyCloudy: return 2
        case .mostlyCloudy, .cloudy: return 3
        case .foggy, .haze: return 45
        case .drizzle: return 51
        case .rain: return 61
        case .heavyRain: return 65
        case .snow, .flurries: return 71
        case .heavySnow, .blizzard: return 75
        case .sleet, .freezingRain, .freezingDrizzle, .wintryMix: return 77
        case .strongStorms, .tropicalStorm, .hurricane: return 95
        case .thunderstorms: return 95
        case .hail, .blowingSnow: return 96
        case .windy, .breezy: return 3
        case .smoky, .blowingDust: return 45
        case .frigid, .hot: return 0
        case .isolatedThunderstorms, .scatteredThunderstorms: return 95
        case .sunFlurries: return 71
        case .sunShowers: return 61
        @unknown default: return 0
        }
    }
    
    // WMO Weather interpretation codes
    private static func weatherCodeToInfo(_ code: Int) -> (condition: String, symbol: String) {
        switch code {
        case 0:
            return ("晴朗", "sun.max.fill")
        case 1, 2, 3:
            return ("多雲", "cloud.sun.fill")
        case 45, 48:
            return ("霧", "cloud.fog.fill")
        case 51, 53, 55:
            return ("毛毛雨", "cloud.drizzle.fill")
        case 61, 63, 65:
            return ("雨", "cloud.rain.fill")
        case 71, 73, 75:
            return ("雪", "cloud.snow.fill")
        case 77:
            return ("雪粒", "cloud.snow.fill")
        case 80, 81, 82:
            return ("陣雨", "cloud.heavyrain.fill")
        case 85, 86:
            return ("陣雪", "cloud.snow.fill")
        case 95:
            return ("雷雨", "cloud.bolt.rain.fill")
        case 96, 99:
            return ("雷雨冰雹", "cloud.bolt.rain.fill")
        default:
            return ("未知", "cloud.fill")
        }
    }
}

// MARK: - Weather Animation Style
enum WeatherStyle: String, CaseIterable, Identifiable {
    case realistic = "realistic"
    case glassmorphic = "glassmorphic"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .realistic: return "擬真動畫"
        case .glassmorphic: return "磨砂擬態"
        }
    }
}
