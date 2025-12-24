import Foundation

enum GooglePollenError: Error {
    case invalidURL
    case noData
    case decodingError
}

final class GooglePollenService: Sendable {
    static let shared = GooglePollenService()
    
    private let apiKey: String
    private let baseURL = "https://pollen.googleapis.com/v1/forecast:lookup"
    
    private init() {
        // Используем тот же ключ, что и для карт, если не указан отдельный
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String ?? ""
    }
    
    /// Получение данных о пыльце от Google
    func fetchPollenData(lat: Double, lon: Double) async throws -> (tree: Double, grass: Double, weed: Double) {
        guard !apiKey.isEmpty else {
            print("Error: GOOGLE_MAPS_API_KEY is empty")
            return (0, 0, 0)
        }
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "location.latitude", value: "\(lat)"),
            URLQueryItem(name: "location.longitude", value: "\(lon)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "days", value: "1")
        ]
        
        guard let url = components?.url else { throw GooglePollenError.invalidURL }

        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.addValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ Google Pollen API error: \(httpResponse.statusCode)")
            print("❌ Google Response: \(errorBody)")
            throw GooglePollenError.noData
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(GooglePollenResponse.self, from: data)
        
        // Google возвращает индексы в массиве dailyInfo
        guard let dailyInfo = result.dailyInfo.first else { return (0, 0, 0) }
        
        var tree: Double = 0
        var grass: Double = 0
        var weed: Double = 0
        
        for pInfo in dailyInfo.pollenTypeInfo {
            switch pInfo.code {
            case .GRASS: grass = Double(pInfo.indexInfo?.value ?? 0)
            case .TREE: tree = Double(pInfo.indexInfo?.value ?? 0)
            case .WEED: weed = Double(pInfo.indexInfo?.value ?? 0)
            }
        }
        
        return (tree, grass, weed)
    }
}

// MARK: - Models
struct GooglePollenResponse: Codable {
    let dailyInfo: [GoogleDailyInfo]
}

struct GoogleDailyInfo: Codable {
    let pollenTypeInfo: [GooglePollenTypeInfo]
}

struct GooglePollenTypeInfo: Codable {
    let code: PollenType
    let indexInfo: GoogleIndexInfo?
    
    enum PollenType: String, Codable {
        case GRASS, TREE, WEED
    }
}

struct GoogleIndexInfo: Codable {
    let value: Int?
    let category: String?
}

