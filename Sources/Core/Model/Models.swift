import Foundation
import GRDB

struct PollenTile: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "pollen_tiles" }
    
    let h3Index: String
    var treeIndex: Double
    var grassIndex: Double
    var weedIndex: Double
    var riskLevel: Double
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case h3Index = "h3_index"
        case treeIndex = "tree_index"
        case grassIndex = "grass_index"
        case weedIndex = "weed_index"
        case riskLevel = "risk_level"
        case updatedAt = "updated_at"
    }

    enum Columns {
        static let h3Index = Column(CodingKeys.h3Index)
        static let treeIndex = Column(CodingKeys.treeIndex)
        static let grassIndex = Column(CodingKeys.grassIndex)
        static let weedIndex = Column(CodingKeys.weedIndex)
        static let riskLevel = Column(CodingKeys.riskLevel)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

struct DiaryEntry: Codable, FetchableRecord, PersistableRecord {
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
}

