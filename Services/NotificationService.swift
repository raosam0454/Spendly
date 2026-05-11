import Foundation
import UserNotifications

enum NotificationError: LocalizedError {
    case permissionDenied
    case schedulingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied. Enable notifications in Settings."
        case .schedulingFailed(let error):
            return "Failed to schedule notification: \(error.localizedDescription)"
        }
    }
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(hour: Int = 20, minute: Int = 0) async throws {
        let center = UNUserNotificationCenter.current()
        // remove old one first so we dont get duplicates
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Daily Spending Check"
        content.body = "Don't forget to log today's expenses in Spendly"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error)
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }

    func scheduleBudgetAlert(categoryName: String, percentage: Int, categoryID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let identifier = "budget_\(categoryID)_\(percentage)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        if percentage >= 100 {
            content.title = "Budget Exceeded!"
            content.body = "You've gone over your \(categoryName) budget."
        } else {
            content.title = "Budget Warning"
            content.body = "You've used \(percentage)% of your \(categoryName) budget."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func removeAllBudgetAlerts() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let budgetIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("budget_") }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: budgetIDs)
        }
    }
}
