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
            print("Failed to update map data: \(error)")
        }
        
        isUpdating = false
    }
}

