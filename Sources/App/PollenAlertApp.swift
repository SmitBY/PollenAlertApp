import SwiftUI
import GoogleMaps
import BackgroundTasks

@main
struct PollenAlertApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    @MainActor
    init() {
        // Инициализация Google Maps API Key из Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
            GMSServices.provideAPIKey(apiKey)
        }
        
        // Ранняя инициализация БД в фоновом потоке, чтобы избежать фризов на Main Thread
        Task.detached(priority: .userInitiated) {
            _ = DatabaseManager.shared
        }
        
        // Запрос разрешений на пуши
        NotificationService.shared.requestAuthorization()
        
        // Регистрация фоновой задачи
        BackgroundRefreshService.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            MapView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // Планируем обновление, когда приложение уходит в фон
                BackgroundRefreshService.shared.schedule()
            }
        }
    }
}

