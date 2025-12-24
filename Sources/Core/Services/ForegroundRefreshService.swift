import Foundation
import CoreLocation

/// Сервис для обновления данных каждый час, когда приложение открыто
@MainActor
final class ForegroundRefreshService {
    static let shared = ForegroundRefreshService()
    
    private var timer: Timer?
    private let pollenRepository = PollenRepository.shared
    private let locationManager = LocationManager.shared
    
    private init() {}
    
    /// Запустить таймер для обновления каждый час
    func start() {
        stop() // Останавливаем предыдущий таймер если есть
        
        // Вычисляем время до следующего целого часа
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .second], from: now)
        
        guard let currentMinute = components.minute,
              let currentSecond = components.second else {
            // Fallback: запускаем через час
            scheduleTimer(interval: 3600)
            return
        }
        
        // Вычисляем секунды до следующего часа
        let secondsUntilNextHour = 3600 - (currentMinute * 60 + currentSecond)
        
        // Сначала запускаем обновление через вычисленное время
        Task {
            try? await Task.sleep(nanoseconds: UInt64(secondsUntilNextHour) * 1_000_000_000)
            await performUpdate()
            
            // Затем запускаем таймер на каждый час
            scheduleTimer(interval: 3600)
        }
    }
    
    private func scheduleTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performUpdate()
            }
        }
        print("⏰ Таймер обновления запущен (интервал: \(interval) сек)")
    }
    
    /// Остановить таймер
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Выполнить обновление данных
    private func performUpdate() async {
        guard let location = locationManager.lastLocation else {
            print("⚠️ Нет местоположения для обновления")
            return
        }
        
        do {
            try await pollenRepository.updatePollenData(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude
            )
            print("✅ Обновление данных в foreground завершено")
        } catch {
            print("❌ Ошибка обновления данных в foreground: \(error)")
        }
    }
}

