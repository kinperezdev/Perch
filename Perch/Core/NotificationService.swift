import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    private(set) var authorized = false
    @ObservationIgnored private let prefs: PreferencesStore

    init(prefs: PreferencesStore) {
        self.prefs = prefs
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { [weak self] in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run { self?.authorized = settings.authorizationStatus == .authorized }
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        authorized = granted
        return granted
    }

    func mirror(_ checkIn: CheckIn) {
        guard prefs.notificationsMirror, authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = checkIn.kind.displayName
        content.body = checkIn.message
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: checkIn.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
