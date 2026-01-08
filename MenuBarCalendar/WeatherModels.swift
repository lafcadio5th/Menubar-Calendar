import Foundation

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
    init(from response: OpenMeteoResponse) {
        self.temperature = response.current.temperature_2m
        self.feelsLike = response.current.apparent_temperature
        self.humidity = response.current.relative_humidity_2m / 100.0
        self.weatherCode = response.current.weather_code
        
        // Map WMO weather code to condition and SF Symbol
        let weatherInfo = Self.weatherCodeToInfo(response.current.weather_code)
        self.condition = weatherInfo.condition
        self.symbolName = weatherInfo.symbol
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
