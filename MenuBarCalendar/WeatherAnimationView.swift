import SwiftUI

struct WeatherAnimationView: View {
    let weatherCode: Int
    let timeOfDay: Int
    let style: WeatherStyle
    var variant: Int = 0 // Default to 0
    
    var body: some View {
        // 使用 Metal 渲染器，它自己處理了背景漸層和所有動畫
        MetalWeatherView(weatherCode: weatherCode, timeOfDay: timeOfDay, style: style, variant: variant)
            .edgesIgnoringSafeArea(.all)
    }
}
