//
//  NotificationManager.swift
//  RoostRepair
//
//  Wraps UNUserNotificationCenter for the local reminder queue (Screen 13)
//  and the global notifications toggle in Settings. No remote push, fully local.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    /// Ask once; returns whether notifications are authorised.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Schedule a daily-repeating local notification at the reminder's time.
    func schedule(_ reminder: Reminder) {
        cancel(reminder)
        guard reminder.enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Roost Repair"
        content.body = "\(reminder.title) — \(reminder.kind.title)"
        content.sound = .default

        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.notificationID,
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.notificationID])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Re-sync the whole queue (used after toggling the global setting).
    func resync(_ reminders: [Reminder], enabled: Bool) {
        cancelAll()
        guard enabled else { return }
        reminders.forEach { schedule($0) }
    }

    /// Fire a one-off confirmation a few seconds out (used by "Add Reminder" test).
    func fireSoon(title: String, body: String, seconds: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "roost-oneoff-\(UUID().uuidString)",
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
