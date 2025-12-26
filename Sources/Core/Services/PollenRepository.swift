import Foundation
import GRDB

final class PollenRepository: Sendable {
    nonisolated static let shared = PollenRepository()
    private let dbManager = DatabaseManager.shared
    private let googlePollenService = GooglePollenService.shared
    private let airQualityService = AirQualityService.shared
    private let tomorrowService = TomorrowService.shared
    
    /// Обновить данные для текущей локации
    func updatePollenData(lat: Double, lon: Double, force: Bool = false) async throws {
        // 1. Получаем H3 индекс
        let h3Index = GeoUtils.latLonToH3(lat: lat, lon: lon)
        guard !h3Index.isEmpty else { return }
        
        // 2. Проверяем, не обновлялись ли мы недавно (менее часа назад)
        if !force {
            if let existingTile = try await getTile(h3Index: h3Index) {
                let timeSinceLastUpdate = Date().timeIntervalSince(existingTile.updatedAt)
                if timeSinceLastUpdate < 3600 {
                    print("ℹ️ Данные для \(h3Index) еще свежие (\(Int(timeSinceLastUpdate/60)) мин назад), пропуск обновления")
                    return
                }
            }
        }
        
        // 3. Загружаем данные о пыльце
        let (tree, grass, weed): (Double, Double, Double)
        do {
            (tree, grass, weed) = try await googlePollenService.fetchPollenData(lat: lat, lon: lon)
        } catch {
            print("Google Pollen API failed, falling back to Tomorrow.io: \(error)")
            (tree, grass, weed) = try await tomorrowService.fetchPollenData(lat: lat, lon: lon)
        }
        
        // 3. Загружаем данные о качестве воздуха (параллельно если возможно, но тут последовательно для простоты)
        var aqi: Int? = nil
        do {
            aqi = try await airQualityService.fetchAirQuality(lat: lat, lon: lon)
        } catch {
            print("Google Air Quality API failed: \(error)")
        }
        
        // 4. Считаем риск с учетом воздуха
        var risk = RiskAlgorithm.calculateRisk(tree: tree, grass: grass, weed: weed, aqi: aqi)
        
        // 5. Применяем Z-фильтр (временной), если есть старые данные
        if let previousTile = try await getTile(h3Index: h3Index) {
            risk = RiskAlgorithm.applyZFilter(previous: previousTile.riskLevel, current: risk, next: risk) // упрощенно: next = current
        }
        
        // 6. Применяем ветровую коррекцию (учет соседних тайлов)
        let neighborIndices = GeoUtils.getNeighbors(for: h3Index)
        var neighborRisks: [Double] = []
        for index in neighborIndices {
            if let neighborTile = try await getTile(h3Index: index) {
                neighborRisks.append(neighborTile.riskLevel)
            }
        }
        risk = RiskAlgorithm.applyWindCorrection(currentRisk: risk, neighborsRisks: neighborRisks)
        
        print("✅ Данные получены и обработаны! Финальный риск: \(risk), AQI: \(String(describing: aqi))")

        // 7. Сохраняем в БД
        let tile = PollenTile(
            h3Index: h3Index,
            treeIndex: tree,
            grassIndex: grass,
            weedIndex: weed,
            riskLevel: risk,
            aqi: aqi,
            updatedAt: Date()
        )
        
        let history = PollenHistory(
            id: nil,
            h3Index: h3Index,
            treeIndex: tree,
            grassIndex: grass,
            weedIndex: weed,
            riskLevel: risk,
            aqi: aqi,
            date: Date()
        )
        
        // 7. Проверка персонального риска для уведомления
        await MainActor.run {
            let personalLevel = PersonalRiskService.shared.getPersonalRiskLevel(for: tile)
            if personalLevel > 80 {
                NotificationService.shared.notifyHighRisk(level: personalLevel)
            }
        }

        try await dbManager.dbQueue.write { db in
            try tile.save(db)
            try history.save(db)
            print("💾 Данные тайла \(h3Index) успешно сохранены в БД и историю")
        }
    }
    
    /// Получить историю для тайла
    func getHistory(h3Index: String, limit: Int = 24) async throws -> [PollenHistory] {
        try await dbManager.dbQueue.read { db in
            try PollenHistory
                .filter(PollenHistory.Columns.h3Index == h3Index)
                .order(PollenHistory.Columns.date.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    /// Получить историю для всех тайлов (например, для общего графика)
    func getAllHistory(limit: Int = 100) async throws -> [PollenHistory] {
        try await dbManager.dbQueue.read { db in
            try PollenHistory
                .order(PollenHistory.Columns.date.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    /// Получить данные для тайла
    func getTile(h3Index: String) async throws -> PollenTile? {
        try await dbManager.dbQueue.read { db in
            try PollenTile.fetchOne(db, key: h3Index)
        }
    }
}

