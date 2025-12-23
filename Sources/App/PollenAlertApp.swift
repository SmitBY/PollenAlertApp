import SwiftUI
import GoogleMaps

@main
struct PollenAlertApp: App {
    
    init() {
        // Инициализация Google Maps API Key из Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
            GMSServices.provideAPIKey(apiKey)
        }
        
        // Запрос разрешений на пуши
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            MapView()
        }
    }
}

