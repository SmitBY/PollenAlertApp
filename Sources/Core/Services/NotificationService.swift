import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
class NotificationService {
    static let shared = NotificationService()
    
    var isAuthorized = false
    
    private init() {
        Task {
            await checkAuthorization()
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if let error = error {
                    print("❌ Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = settings.authorizationStatus == .authorized
    }
    
    /// Отправляет немедленное уведомление о высоком уровне риска
    func notifyHighRisk(level: Double) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Внимание: высокий риск!"
        content.body = "Ваш персональный уровень опасности: \(Int(level))%. Будьте осторожны на улице."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "high_risk_alert",
            content: content,
            trigger: nil // Немедленно
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}
