import Foundation

// MARK: - Форматтеры (порт DateFormatters.kt)
// Форматтеры зависят от локали устройства, поэтому создаются по требованию.

enum Formatters {
    // "12 марта 2022" / "12 March 2022"
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return formatter.string(from: date)
    }

    // "12.03.2022"
    static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    // "09:30"
    static func formatTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // "март 2026" / "October 2026"
    static func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    // Короткое имя дня недели с началом недели в понедельник: Пн, Вт, …
    static func weekdayShort(isoWeekday: Int) -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // понедельник
        let symbols = calendar.shortWeekdaySymbols
        guard symbols.count == 7 else { return "" }
        // symbols начинаются с воскресенья; ISO 1=пн … 7=вс
        let index = isoWeekday % 7
        return symbols[index]
    }

    // "1:05:30" при наличии часов, иначе "5:30"
    static func formatDuration(totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatWeight(_ weightKg: Double) -> String {
        String(format: "%.1f", weightKg)
    }

    static func formatGrams(_ grams: Double) -> String {
        String(format: "%.1f", grams)
    }
}

// MARK: - Возраст собаки (порт CalculateDogAgeUseCase.kt)

enum DogAgeCalculator {
    /// Полные годы и месяцы на текущий день; дата в будущем даёт нулевой возраст.
    static func age(birthDate: Date, today: Date = Date()) -> DogAge {
        var calendar = Calendar.current
        calendar.locale = .current
        let components = calendar.dateComponents([.year, .month], from: birthDate.startOfDay, to: today.startOfDay)
        let years = max(0, components.year ?? 0)
        let months = max(0, components.month ?? 0)
        return DogAge(years: years, months: months)
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// ISO-номер дня недели: 1 = понедельник … 7 = воскресенье
    var weekdayISO: Int {
        let systemWeekday = Calendar.current.component(.weekday, from: self)
        // Система: 1 = воскресенье; ISO: 1 = понедельник
        return systemWeekday == 1 ? 7 : systemWeekday - 1
    }

    /// Локальные компоненты даты (без времени)
    var dateComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: self)
    }

    /// Число дней между датами (по календарным дням, не по 24 часам)
    func daysSince(_ earlier: Date) -> Int {
        Calendar.current.dateComponents([.day], from: earlier.startOfDay, to: self.startOfDay).day ?? 0
    }
}
