import Foundation
import UserNotifications
import UIKit

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge, .list]
    }
}

enum NotificationManager {
    static func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        configure()
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Error solicitando autorización de notificaciones: \(error.localizedDescription)")
            return false
        }
    }

    static func scheduleReminder(for document: LifeDocument) {
        cancelReminder(for: document)

        guard document.reminderEnabled, let expirationDate = document.expirationDate else {
            return
        }

        Task {
            let granted = await requestAuthorization()
            guard granted else {
                print("Permiso de notificaciones no concedido")
                return
            }

            let center = UNUserNotificationCenter.current()
            let calendar = Calendar.current
            let frequency = document.recurrenceFrequency
            let lm = LanguageManager.shared

            let content = UNMutableNotificationContent()
            if let amountText = document.formattedAmount {
                content.title = lm.tr("notif.dueTitle", document.title, amountText)
                content.body = lm.tr("notif.dueBody", document.title, amountText, frequency.localizedName)
            } else {
                content.title = lm.tr("notif.dueNoAmtTitle", document.title)
                content.body = lm.tr("notif.dueNoAmtBody", document.title, frequency.localizedName)
            }
            content.sound = .default
            content.badge = 1

            switch frequency {
            case .never:
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: expirationDate)
                dateComponents.hour = 9
                dateComponents.minute = 0

                if let scheduledDate = calendar.date(from: dateComponents) {
                    let trigger: UNNotificationTrigger
                    if scheduledDate > Date() {
                        trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                    } else if calendar.isDateInToday(expirationDate) {
                        // If expiration is today and 9am already passed, trigger in 60 seconds
                        trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
                    } else {
                        // Date is in the past, skip
                        return
                    }

                    let request = UNNotificationRequest(
                        identifier: "\(document.id.uuidString)-due",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(request)
                    print("Notificación programada para \(document.title)")
                }

            case .monthly:
                var dateComponents = calendar.dateComponents([.day], from: expirationDate)
                dateComponents.hour = 9
                dateComponents.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(document.id.uuidString)-due-monthly",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)

            case .quarterly:
                // Schedule 4 quarterly reminders over the coming year
                for i in 0..<4 {
                    if let quarterlyDate = calendar.date(byAdding: .month, value: i * 3, to: expirationDate) {
                        var dateComponents = calendar.dateComponents([.year, .month, .day], from: quarterlyDate)
                        dateComponents.hour = 9
                        dateComponents.minute = 0

                        if let scheduledDate = calendar.date(from: dateComponents), scheduledDate > Date() {
                            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                            let request = UNNotificationRequest(
                                identifier: "\(document.id.uuidString)-due-q\(i)",
                                content: content,
                                trigger: trigger
                            )
                            try? await center.add(request)
                        }
                    }
                }

            case .yearly:
                var dateComponents = calendar.dateComponents([.month, .day], from: expirationDate)
                dateComponents.hour = 9
                dateComponents.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(document.id.uuidString)-due-yearly",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }

            // 7 Days Prior Alert (for one-time or initial expiration)
            if let date7DaysBefore = calendar.date(byAdding: .day, value: -7, to: expirationDate), date7DaysBefore > Date() {
                var prevComponents = calendar.dateComponents([.year, .month, .day], from: date7DaysBefore)
                prevComponents.hour = 9
                prevComponents.minute = 0

                let prevContent = UNMutableNotificationContent()
                prevContent.title = lm.tr("notif.prevTitle", document.title)
                prevContent.body = lm.tr("notif.prevBody", document.title)
                prevContent.sound = .default

                let prevTrigger = UNCalendarNotificationTrigger(dateMatching: prevComponents, repeats: false)
                let prevRequest = UNNotificationRequest(
                    identifier: "\(document.id.uuidString)-7days",
                    content: prevContent,
                    trigger: prevTrigger
                )
                try? await center.add(prevRequest)
            }
        }
    }

    static func cancelReminder(for document: LifeDocument) {
        let center = UNUserNotificationCenter.current()
        var identifiers = [
            "\(document.id.uuidString)-due",
            "\(document.id.uuidString)-due-monthly",
            "\(document.id.uuidString)-due-yearly",
            "\(document.id.uuidString)-7days"
        ]
        for i in 0..<4 {
            identifiers.append("\(document.id.uuidString)-due-q\(i)")
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
