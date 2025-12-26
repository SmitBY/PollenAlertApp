import Foundation
import SwiftUI
import GoogleMaps
import Observation

@Observable
@MainActor
class MapViewModel {
    var tiles: [PollenTile] = []
    var isUpdating = false
    
    private let repository = PollenRepository.shared
    
    func updateVisibleRegion(lat: Double, lon: Double) async {
        guard !isUpdating else { return }
        isUpdating = true
        
        do {
            // Обновляем данные для центральной точки
            try await repository.updatePollenData(lat: lat, lon: lon)
            
            // Загружаем тайлы для отображения
            await loadTilesForLocation(lat: lat, lon: lon)
        } catch {
            print("Failed to update map data: \(error)")
        }
        
        isUpdating = false
    }
    
    /// Загрузить последние данные из БД для текущей локации. Если данных нет или они устарели - обновить через API
    func loadLastData(lat: Double, lon: Double) async {
        let centerH3 = GeoUtils.latLonToH3(lat: lat, lon: lon)
        
        // Пытаемся загрузить данные из БД
        await loadTilesForLocation(lat: lat, lon: lon)
        
        // Проверяем, есть ли данные для центральной точки
        let hasCenterTile = tiles.contains { $0.h3Index == centerH3 }
        
        // Проверяем, не устарели ли данные (старше 1 часа)
        let isDataStale = tiles.first { $0.h3Index == centerH3 }
            .map { Date().timeIntervalSince($0.updatedAt) > 3600 } ?? true
        
        // Если данных нет или они устарели - обновляем через API
        if !hasCenterTile || isDataStale {
            print("📥 Данных нет или они устарели, обновляем через API...")
            await updateVisibleRegion(lat: lat, lon: lon)
        } else {
            print("✅ Используем данные из БД")
        }
    }
    
    private func loadTilesForLocation(lat: Double, lon: Double) async {
        do {
            // Получаем соседей для отображения сетки вокруг пользователя
            let centerH3 = GeoUtils.latLonToH3(lat: lat, lon: lon)
            let neighbors = GeoUtils.getNeighbors(for: centerH3)
            let allIndices = [centerH3] + neighbors
            
            var newTiles: [PollenTile] = []
            for index in allIndices {
                if let tile = try await repository.getTile(h3Index: index) {
                    newTiles.append(tile)
                }
            }
            
            self.tiles = newTiles
        } catch {
            print("Failed to load tiles from DB: \(error)")
        }
    }
}

