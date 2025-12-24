import Foundation

enum TomorrowError: Error {
    case invalidURL
    case noData
    case decodingError
}

final class TomorrowService: Sendable {
    static let shared = TomorrowService()
    
    private let apiKey: String
    private let baseURL = "https://api.tomorrow.io/v4/weather/realtime"
    
    private init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "TOMORROW_API_KEY") as? String ?? ""
        self.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.apiKey.isEmpty {
            print("⚠️ Warning: TOMORROW_API_KEY is missing in Info.plist or Keys.xcconfig")
        }
    }
    
    /// Получение данных о пыльце для конкретных координат
    func fetchPollenData(lat: Double, lon: Double) async throws -> (tree: Double, grass: Double, weed: Double) {
        guard !apiKey.isEmpty else {
            print("Error: TOMORROW_API_KEY is empty")
            return (0, 0, 0)
        }
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "location", value: "\(lat),\(lon)"),
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "fields", value: "treeIndex,grassIndex,weedIndex")
        ]
        
        guard let url = components?.url else { throw TomorrowError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TomorrowError.noData
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(TomorrowResponse.self, from: data)
        
        let tree = result.data.values.treeIndex ?? 0
        let grass = result.data.values.grassIndex ?? 0
        let weed = result.data.values.weedIndex ?? 0
        
        return (tree, grass, weed)
    }
}

// MARK: - Response Models
struct TomorrowResponse: Codable {
    let data: TomorrowData
}

struct TomorrowData: Codable {
    let values: TomorrowValues
}

struct TomorrowValues: Codable {
    let treeIndex: Double?
    let grassIndex: Double?
    let weedIndex: Double?
}

