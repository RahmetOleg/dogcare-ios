import Foundation
import UserNotifications

// MARK: - Планировщик уведомлений (порт ReminderScheduler / VaccineReminderScheduler)
// WorkManager заменён на UNUserNotificationCenter: напоминания по дням недели —
// повторяющиеся триггеры, прививки — одиночный триггер за 3 дня до следующей даты.

enum NotificationScheduler {
    private static let reminderTimePrefix = "reminder_"
    private static let vaccineTimePrefix = "vaccine_reminder_"
    private static let vaccineDaysBefore = 3

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    // MARK: Напоминания по расписанию (лекарства и кормление)

    /// Ставит повторяющиеся уведомления: по одному на каждый выбранный день недели.
    static func schedule(reminder: Reminder, dogName: String) {
        guard reminder.isEnabled, !reminder.daysOfWeek.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = L("notification_reminder_title", typeLabel(reminder.type), dogName)
        content.body = L("notification_reminder_text", reminder.title, reminder.timeText)
        content.sound = .default

        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute
        for weekday in reminder.daysOfWeek.sorted() {
            components.weekday = isoToSystemWeekday(weekday)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminderTimePrefix + reminder.id + "_\(weekday)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelReminder(reminderId: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(reminderTimePrefix + reminderId) }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: Прививки: push в 09:00 локального времени за 3 дня до nextDueDate

    static func scheduleVaccineReminder(vaccine: Vaccine, dogName: String, today: Date = Date()) {
        guard let nextDueDate = vaccine.nextDueDate else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: nextDueDate)
        components.day = (components.day ?? 0) - vaccineDaysBefore
        components.hour = 9
        components.minute = 0
        guard let fireDate = Calendar.current.date(from: components), fireDate > today else {
            // Срок уже наступил — напоминание бессмысленно
            return
        }

        let content = UNMutableNotificationContent()
        content.title = L("notification_vaccine_title")
        content.body = L(
            "notification_vaccine_text",
            dogName,
            vaccine.name,
            Formatters.formatShortDate(nextDueDate)
        )
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: vaccineTimePrefix + vaccine.id,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelVaccineReminder(vaccineId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [vaccineTimePrefix + vaccineId])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: Вспомогательные

    private static func typeLabel(_ type: ReminderType) -> String {
        switch type {
        case .medication: return L("notification_type_medication")
        case .feeding: return L("notification_type_feeding")
        }
    }

    /// ISO-номер дня (1 = понедельник) в системный номер недели (1 = воскресенье)
    private static func isoToSystemWeekday(_ isoWeekday: Int) -> Int {
        isoWeekday % 7 + 1
    }
}
