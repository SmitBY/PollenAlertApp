import Foundation
import GRDB

final class DatabaseManager: Sendable {
    nonisolated static let shared = DatabaseManager()
    
    let dbQueue: DatabaseQueue
    
    private init() {
        do {
            let fileManager = FileManager.default
            let dbPath = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("pollen.sqlite")
                .path
            
            dbQueue = try DatabaseQueue(path: dbPath)
            try setupDatabase()
        } catch {
            fatalError("Could not initialize database: \(error)")
        }
    }
    
    private func setupDatabase() throws {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1") { db in
            // Таблица для хранения данных о пыльце в тайлах
            try db.create(table: "pollen_tiles") { t in
                t.column("h3_index", .text).primaryKey()
                t.column("tree_index", .double).notNull()
                t.column("grass_index", .double).notNull()
                t.column("weed_index", .double).notNull()
                t.column("risk_level", .double).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            
            // Таблица для дневника пользователя
            try db.create(table: "diary_entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .datetime).notNull()
                t.column("feeling_score", .integer).notNull() // 0-5
                t.column("symptoms", .text)
                t.column("h3_index", .text).notNull()
            }
        }
        
        migrator.registerMigration("v2") { db in
            // Таблица для хранения истории изменения пыльцы
            try db.create(table: "pollen_history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("h3_index", .text).notNull().indexed()
                t.column("tree_index", .double).notNull()
                t.column("grass_index", .double).notNull()
                t.column("weed_index", .double).notNull()
                t.column("risk_level", .double).notNull()
                t.column("date", .datetime).notNull().indexed()
            }
        }
        
        migrator.registerMigration("v3") { db in
            // Добавляем AQI (Air Quality Index) в существующие таблицы
            try db.alter(table: "pollen_tiles") { t in
                t.add(column: "aqi", .integer)
            }
            try db.alter(table: "pollen_history") { t in
                t.add(column: "aqi", .integer)
            }
        }
        
        try migrator.migrate(dbQueue)
    }
}

