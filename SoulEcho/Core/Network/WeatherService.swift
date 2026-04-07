import Foundation
import Observation

struct GeoResponse: Codable {
    let latitude: String
    let longitude: String
}

@Observable
class WeatherService {
    var recommendation: WeatherRecommendation?
    var isLoading = false
    
    func fetchWeatherRecommendation() async {
        isLoading = true
        defer { isLoading = false }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        let session = URLSession(configuration: config)
        
        do {
            // 1. Get Location based on IP
            let geoUrl = URL(string: "https://get.geojs.io/v1/ip/geo.json")!
            let (geoData, _) = try await session.data(from: geoUrl)
            let geoInfo = try JSONDecoder().decode(GeoResponse.self, from: geoData)
            
            guard let lat = Double(geoInfo.latitude), let lon = Double(geoInfo.longitude) else { return }
            
            // 2. Fetch Open-Meteo Weather
            let weatherUrlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
            guard let weatherUrl = URL(string: weatherUrlString) else { return }
            
            let (weatherData, _) = try await session.data(from: weatherUrl)
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: weatherData)
            
            let current = weatherResponse.currentWeather
            recommendation = WeatherRecommendation(temperature: current.temperature, weatherCode: current.weathercode)
            
        } catch {
            print("Failed to fetch weather: \(error.localizedDescription)")
            recommendation = WeatherRecommendation(temperature: 20, weatherCode: 1) // Fallback positive message
        }
    }
}
