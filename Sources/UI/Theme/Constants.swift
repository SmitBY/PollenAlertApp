import Foundation

struct Constants {
    // Коэффициенты для алгоритма риска (пункт 4 спецификации)
    static let treeWeight: Double = 0.4
    static let grassWeight: Double = 0.3
    static let weedWeight: Double = 0.3
    
    // Фактор влияния воздуха (0.005 означает +50% риска при AQI 100)
    static let aqiImpactFactor: Double = 0.005
    
    // Фактор ветра
    static let windFactor: Double = 0.1
    
    // H3 разрешение
    static let h3Resolution: Int = 8
    
    // Дизайн (цвета в коде лучше не хранить, использовать Assets, но здесь для примера)
    // Никакого синего или фиолетового (ID: 8555363)
    struct Design {
        static let inactiveOpacity: Double = 0.4
        static let secondaryGrey = "SecondaryGrey"
    }
}

