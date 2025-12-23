import Foundation
import GRDB

class PollenRepository {
    static let shared = PollenRepository()
    private let dbManager = DatabaseManager.shared
    private let googlePollenService = GooglePollenService.shared
    private let tomorrowService = TomorrowService.shared
    
    /// Обновить данные для текущей локации
    func updatePollenData(lat: Double, lon: Double) async throws {
        // 1. Получаем H3 индекс
        let h3Index = GeoUtils.latLonToH3(lat: lat, lon: lon)
        guard !h3Index.isEmpty else { return }
        
        // 2. Загружаем данные (предпочтительно из Google Pollen API)
        let (tree, grass, weed): (Double, Double, Double)
        do {
            (tree, grass, weed) = try await googlePollenService.fetchPollenData(lat: lat, lon: lon)
        } catch {
            print("Google Pollen API failed, falling back to Tomorrow.io: \(error)")
            (tree, grass, weed) = try await tomorrowService.fetchPollenData(lat: lat, lon: lon)
        }
        
        // 3. Считаем базовый риск
        var risk = RiskAlgorithm.calculateRisk(tree: tree, grass: grass, weed: weed)
        
        // 4. Применяем Z-фильтр (временной), если есть старые данные
        if let previousTile = try await getTile(h3Index: h3Index) {
            risk = RiskAlgorithm.applyZFilter(previous: previousTile.riskLevel, current: risk, next: risk) // упрощенно: next = current
        }
        
        // 5. Применяем ветровую коррекцию (учет соседних тайлов)
        let neighborIndices = GeoUtils.getNeighbors(for: h3Index)
        var neighborRisks: [Double] = []
        for index in neighborIndices {
            if let neighborTile = try await getTile(h3Index: index) {
                neighborRisks.append(neighborTile.riskLevel)
            }
        }
        risk = RiskAlgorithm.applyWindCorrection(currentRisk: risk, neighborsRisks: neighborRisks)
        
        print("✅ Данные получены и обработаны! Финальный риск: \(risk)")

        // 6. Сохраняем в БД
        let tile = PollenTile(
            h3Index: h3Index,
            treeIndex: tree,
            grassIndex: grass,
            weedIndex: weed,
            riskLevel: risk,
            updatedAt: Date()
        )
        
        // 7. Проверка персонального риска для уведомления
        let personalLevel = PersonalRiskService.shared.getPersonalRiskLevel(for: tile)
        if personalLevel > 80 {
            NotificationService.shared.notifyHighRisk(level: personalLevel)
        }

        try await dbManager.dbQueue.write { db in
            try tile.save(db)
            print("💾 Данные тайла \(h3Index) успешно сохранены в БД")
        }
    }
    
    /// Получить данные для тайла
    func getTile(h3Index: String) async throws -> PollenTile? {
        try await dbManager.dbQueue.read { db in
            try PollenTile.fetchOne(db, key: h3Index)
        }
    }
}

