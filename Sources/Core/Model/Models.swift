import Foundation
import GRDB

struct PollenTile: Codable, FetchableRecord, PersistableRecord, Equatable {
    static var databaseTableName: String { "pollen_tiles" }
    
    let h3Index: String
    var treeIndex: Double
    var grassIndex: Double
    var weedIndex: Double
    var riskLevel: Double
    var aqi: Int? // Индекс качества воздуха (Google AQI)
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case h3Index = "h3_index"
        case treeIndex = "tree_index"
        case grassIndex = "grass_index"
        case weedIndex = "weed_index"
        case riskLevel = "risk_level"
        case aqi
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let h3Index = Column(CodingKeys.h3Index)
        static let treeIndex = Column(CodingKeys.treeIndex)
        static let grassIndex = Column(CodingKeys.grassIndex)
        static let weedIndex = Column(CodingKeys.weedIndex)
        static let riskLevel = Column(CodingKeys.riskLevel)
        static let aqi = Column(CodingKeys.aqi)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

struct DiaryEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static var databaseTableName: String { "diary_entries" }
    
    var id: Int64?
    var date: Date
    var feelingScore: Int
    var symptoms: String?
    var h3Index: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case feelingScore = "feeling_score"
        case symptoms
        case h3Index = "h3_index"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let date = Column(CodingKeys.date)
        static let feelingScore = Column(CodingKeys.feelingScore)
        static let symptoms = Column(CodingKeys.symptoms)
        static let h3Index = Column(CodingKeys.h3Index)
    }

    static func emoji(for score: Int) -> String {
        switch score {
        case 0: return "😫"
        case 1: return "🙁"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😊"
        case 5: return "🤩"
        default: return "❓"
        }
    }

    static func description(for score: Int) -> String {
        switch score {
        case 0: return "Очень плохо"
        case 1: return "Плохо"
        case 2: return "Так себе"
        case 3: return "Нормально"
        case 4: return "Хорошо"
        case 5: return "Отлично"
        default: return "Неизвестно"
        }
    }
}

struct PollenHistory: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static var databaseTableName: String { "pollen_history" }
    
    var id: Int64?
    let h3Index: String
    let treeIndex: Double
    let grassIndex: Double
    let weedIndex: Double
    let riskLevel: Double
    let aqi: Int?
    let date: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case h3Index = "h3_index"
        case treeIndex = "tree_index"
        case grassIndex = "grass_index"
        case weedIndex = "weed_index"
        case riskLevel = "risk_level"
        case aqi
        case date
    }
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let h3Index = Column(CodingKeys.h3Index)
        static let treeIndex = Column(CodingKeys.treeIndex)
        static let grassIndex = Column(CodingKeys.grassIndex)
        static let weedIndex = Column(CodingKeys.weedIndex)
        static let riskLevel = Column(CodingKeys.riskLevel)
        static let aqi = Column(CodingKeys.aqi)
        static let date = Column(CodingKeys.date)
    }
}

