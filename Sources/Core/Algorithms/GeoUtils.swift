import Foundation
import SwiftyH3
import CoreLocation

struct GeoUtils {
    /// Конвертация координат в H3 индекс (res 8)
    static func latLonToH3(lat: Double, lon: Double) -> String {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let latLng = coordinate.h3LatLng
        if let cell = try? latLng.cell(at: .res8) {
            return String(cell.id, radix: 16)
        }
        return ""
    }
    
    /// Получение координат вершин гексагона для отрисовки
    static func getBoundary(for h3IndexStr: String) -> [CLLocationCoordinate2D] {
        guard let id = UInt64(h3IndexStr, radix: 16) else { return [] }
        let cell = H3Cell(id)
        if let boundary = try? cell.boundary {
            return boundary.map { $0.coordinates }
        }
        return []
    }
    
    /// Получение соседних H3 ячеек
    static func getNeighbors(for h3IndexStr: String) -> [String] {
        guard let id = UInt64(h3IndexStr, radix: 16) else { return [] }
        let cell = H3Cell(id)
        if let neighbors = try? cell.gridRing(distance: 1) {
            return neighbors.map { String($0.id, radix: 16) }
        }
        return []
    }
}
