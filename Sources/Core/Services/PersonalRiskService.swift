import Foundation
import GRDB
import Observation

@Observable
@MainActor
class PersonalRiskService {
    static let shared = PersonalRiskService()
    
    private let dbManager = DatabaseManager.shared
    
    // Базовый порог риска (может меняться)
    var riskThreshold: Double = 150.0
    
    private init() {
        Task {
            await loadThreshold()
        }
    }
    
    private func loadThreshold() async {
        // В будущем можно хранить в UserDefaults или отдельной таблице настроек
        // Пока просто используем базовый
    }
    
    /// Анализирует дневник и обновляет пороги если нужно (Байесовское обновление)
    func updateThresholds() async {
        do {
            let entries = try await dbManager.dbQueue.read { db in
                try DiaryEntry.fetchAll(db)
            }
            
            guard !entries.isEmpty else { return }
            
            // Простейшая логика: если много жалоб при текущем риске, снижаем порог
            let badFeelingEntries = entries.filter { $0.feelingScore < 3 }
            
            if badFeelingEntries.count >= 2 {
                var totalRiskAtBadTimes: Double = 0
                var count = 0
                
                for entry in badFeelingEntries {
                    if let tile = try await PollenRepository.shared.getTile(h3Index: entry.h3Index) {
                        totalRiskAtBadTimes += tile.riskLevel
                        count += 1
                    }
                }
                
                if count > 0 {
                    let avgBadRisk = totalRiskAtBadTimes / Double(count)
                    // Устанавливаем порог чуть ниже среднего уровня, когда стало плохо (но не ниже 50)
                    let newThreshold = max(50.0, avgBadRisk * 0.85)
                    
                    self.riskThreshold = newThreshold
                    print("🔄 Порог риска обновлен персонально: \(riskThreshold)")
                }
            }
        } catch {
            print("Failed to update personal thresholds: \(error)")
        }
    }
    
    /// Возвращает персональный уровень риска (0-100%)
    func getPersonalRiskLevel(for tile: PollenTile) -> Double {
        return min(100.0, (tile.riskLevel / riskThreshold) * 100.0)
    }
}

