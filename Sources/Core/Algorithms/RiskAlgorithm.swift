import Foundation

struct RiskAlgorithm {
    /// Итоговая формула с учетом качества воздуха (AQI)
    static func calculateRisk(tree: Double, grass: Double, weed: Double, aqi: Int?) -> Double {
        let normalizedTree = normalize(tree)
        let normalizedGrass = normalize(grass)
        let normalizedWeed = normalize(weed)
        
        let baseRisk = normalizedTree * Constants.treeWeight +
                       normalizedGrass * Constants.grassWeight +
                       normalizedWeed * Constants.weedWeight
        
        // Применяем AQI как множитель: Risk = Base * (1 + AQI * factor)
        // Если AQI нет, множитель будет 1.0 (без изменений)
        let aqiValue = Double(aqi ?? 0)
        let airCorrection = 1.0 + (aqiValue * Constants.aqiImpactFactor)
        
        return baseRisk * airCorrection
    }
    
    /// Нормализация данных (0-5 -> 0-500)
    private static func normalize(_ value: Double) -> Double {
        return value * 100.0
    }
    
    /// Z-фильтр (временной): (p[t-1] + p[t] + p[t+1]) / 3
    static func applyZFilter(previous: Double, current: Double, next: Double) -> Double {
        return (previous + current + next) / 3.0
    }
    
    /// Ветровая коррекция (упрощенно: учет среднего значения соседей)
    static func applyWindCorrection(currentRisk: Double, neighborsRisks: [Double]) -> Double {
        guard !neighborsRisks.isEmpty else { return currentRisk }
        let avgNeighborRisk = neighborsRisks.reduce(0, +) / Double(neighborsRisks.count)
        return currentRisk + (avgNeighborRisk - currentRisk) * Constants.windFactor
    }
}

