import Foundation

enum AirQualityError: Error {
    case invalidURL
    case noData
    case decodingError
}

final class AirQualityService: Sendable {
    static let shared = AirQualityService()
    
    private let apiKey: String
    private let baseURL = "https://airquality.googleapis.com/v1/currentConditions:lookup"
    
    private init() {
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String ?? ""
    }
    
    /// Получение индекса качества воздуха (AQI) от Google
    func fetchAirQuality(lat: Double, lon: Double) async throws -> Int {
        guard !apiKey.isEmpty else {
            print("Error: GOOGLE_MAPS_API_KEY is empty")
            return 0
        }
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components?.url else { throw AirQualityError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let bundleID = Bundle.main.bundleIdentifier {
            request.addValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        
        let body: [String: Any] = [
            "location": [
                "latitude": lat,
                "longitude": lon
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ Google Air Quality API error: \(httpResponse.statusCode)")
            print("❌ Google Response: \(errorBody)")
            throw AirQualityError.noData
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AirQualityResponse.self, from: data)
        
        // Google возвращает массив индексов, ищем Universal AQI или первый доступный
        let aqiValue = result.indexes.first(where: { $0.code == "uaqi" })?.aqi ?? result.indexes.first?.aqi ?? 0
        return aqiValue
    }
}

// MARK: - Models
struct AirQualityResponse: Codable {
    let indexes: [AirQualityIndex]
}

struct AirQualityIndex: Codable {
    let code: String
    let displayName: String
    let aqi: Int
    let category: String
}

