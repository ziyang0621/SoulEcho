import Foundation

struct WeatherResponse: Codable {
    let currentWeather: CurrentWeather

    enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
    }
}

struct CurrentWeather: Codable {
    let temperature: Double
    let weathercode: Int
}

struct WeatherRecommendation {
    let isSuitableForOutdoor: Bool
    let message: String
    
    init(temperature: Double, weatherCode: Int) {
        // WMO codes: 0 (Clear), 1-3 (Partly cloudy), etc.
        let goodWeatherCodes = [0, 1, 2, 3]
        if goodWeatherCodes.contains(weatherCode) && temperature > 10 && temperature < 35 {
            isSuitableForOutdoor = true
            message = String(localized: "天气晴好，非常适合在户外进行几分钟的静态冥想与深呼吸。")
        } else {
            isSuitableForOutdoor = false
            message = String(localized: "现在的天气更适合在舒适的室内进行短暂的沉思与放松。")
        }
    }
}
