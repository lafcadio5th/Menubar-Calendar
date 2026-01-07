import UserNotifications
import AppKit
import Combine

// MARK: - Notification Service
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    
    private override init() {
        super.init()
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("通知授權失敗: \(error)")
            return false
        }
    }
    
    // MARK: - Schedule Notifications
    
    func scheduleEventReminder(for event: CalendarEvent, reminderOffset: TimeInterval) async throws {
        // 檢查授權
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted { return }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "即將到來的事件"
        content.body = event.title
        content.sound = .default
        
        // 計算事件時間
        let eventTime: Date
        if let time = event.time {
            eventTime = time
        } else if let defaultTime = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: event.date) {
            eventTime = defaultTime
        } else {
            return
        }
        
        let triggerDate = eventTime.addingTimeInterval(-reminderOffset)
        if triggerDate <= Date() { return }
        
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    func cancelEventReminder(for eventId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [eventId.uuidString])
    }
}
