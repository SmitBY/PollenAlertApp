import Foundation
import BackgroundTasks
import CoreLocation

final actor BackgroundRefreshService {
    static let shared = BackgroundRefreshService()
    static let taskIdentifier = "com.pollenalert.refresh"
    
    private let pollenRepository = PollenRepository.shared
    private var lastScheduledDate: Date?
    
    private init() {}
    
    /// Регистрация фоновой задачи
    nonisolated func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            Task {
                await self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }
    }
    
    /// Планирование следующего обновления на следующее целое время (12:00, 13:00, 14:00...)
    func schedule() {
        // Сначала отменяем все существующие задачи с этим идентификатором
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        
        // Планируем сразу, так как actor гарантирует последовательное выполнение
        self.performSchedule()
    }
    
    private func performSchedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        
        // Вычисляем следующее целое время (например, если сейчас 12:30, то следующее обновление в 13:00)
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        
        guard let currentHour = components.hour else {
            // Fallback: через час
            let fallbackDate = Date(timeIntervalSinceNow: 3600)
            request.earliestBeginDate = fallbackDate
            submitRequest(request)
            return
        }
        
        // Следующий час
        var nextHourComponents = components
        nextHourComponents.hour = currentHour + 1
        nextHourComponents.minute = 0
        nextHourComponents.second = 0
        
        if let nextHourDate = calendar.date(from: nextHourComponents) {
            // Если мы уже планировали на это время, выходим
            if lastScheduledDate == nextHourDate {
                return
            }
            request.earliestBeginDate = nextHourDate
            lastScheduledDate = nextHourDate
        } else {
            // Fallback: через час
            let fallbackDate = Date(timeIntervalSinceNow: 3600)
            request.earliestBeginDate = fallbackDate
        }
        
        submitRequest(request)
    }
    
    private func submitRequest(_ request: BGAppRefreshTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Фоновая задача успешно запланирована на \(request.earliestBeginDate?.formatted() ?? "неизвестно")")
        } catch let error as NSError {
            lastScheduledDate = nil // Сбрасываем при ошибке, чтобы можно было перепланировать
            if error.code == 1 {
                // Задача уже запланирована - это нормально, не критичная ошибка
                print("ℹ️ Фоновая задача уже запланирована (Code=1 - это нормально)")
            } else {
                print("❌ Не удалось запланировать фоновую задачу: \(error.domain) Code=\(error.code)")
            }
        } catch {
            lastScheduledDate = nil
            print("❌ Не удалось запланировать фоновую задачу: \(error)")
        }
    }
    
    /// Обработка фоновой задачи
    private func handleAppRefresh(task: BGAppRefreshTask) async {
        // Запланируем следующую задачу сразу
        schedule()
        
        let operationQueue = OperationQueue()
        
        task.expirationHandler = {
            operationQueue.cancelAllOperations()
        }
        
        do {
            // Получаем текущее местоположение на главном потоке (требование CLLocationManager)
            if let location = await fetchCurrentLocation() {
                try await pollenRepository.updatePollenData(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude
                )
                task.setTaskCompleted(success: true)
                print("✅ Фоновое обновление успешно завершено")
            } else {
                print("⚠️ Не удалось получить местоположение в фоне")
                task.setTaskCompleted(success: false)
            }
        } catch {
            print("❌ Ошибка фонового обновления: \(error)")
            task.setTaskCompleted(success: false)
        }
    }
    
    @MainActor
    private func fetchCurrentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            let manager = CLLocationManager()
            let delegate = BackgroundLocationRequester(manager: manager) { location in
                continuation.resume(returning: location)
            }
            manager.delegate = delegate
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()
        }
    }
}

/// Вспомогательный класс для разового запроса локации
@MainActor
private class BackgroundLocationRequester: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private let completion: (CLLocation?) -> Void
    private var selfRetainer: BackgroundLocationRequester?

    init(manager: CLLocationManager, completion: @escaping (CLLocation?) -> Void) {
        self.manager = manager
        self.completion = completion
        super.init()
        self.selfRetainer = self
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        cleanup(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Background Location Error: \(error)")
        cleanup(nil)
    }
    
    private func cleanup(_ location: CLLocation?) {
        completion(location)
        selfRetainer = nil
    }
}

