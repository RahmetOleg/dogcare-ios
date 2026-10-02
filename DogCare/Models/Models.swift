import Foundation

// MARK: - Справочник опасных продуктов (порт com.dogcare.core.domain.model.Food)

enum StatusLevel: String, Codable, CaseIterable {
    case safe = "safe"
    case conditionallySafe = "conditionally_safe"
    case dangerous = "dangerous"
    case toxic = "toxic"
    case emergency = "emergency"

    init(fromJSON: String) {
        // В активе статусы хранятся как safe / conditionally_safe / dangerous / toxic / emergency
        self = StatusLevel(rawValue: fromJSON) ?? .conditionallySafe
    }

    var colorKey: String {
        switch self {
        case .safe: return "green"
        case .conditionallySafe: return "yellow"
        case .dangerous: return "orange"
        case .toxic: return "red"
        case .emergency: return "black"
        }
    }
}

struct Food: Identifiable, Equatable {
    let id: String
    let name: String
    let aliases: [String]
    let status: StatusLevel
    let toxicAgent: String?
    let safeForm: String?
    let dangerForms: [String]
    let symptoms: [String]
    let firstAid: String
    let notes: String
}

// Породный риск — всегда «осторожно», никогда не запрет
struct BreedRisk: Identifiable, Equatable {
    var id: String { "\(breedId)#\(foodId)" }
    let breedId: String
    let foodId: String
    let risk: String
}

// MARK: - Профиль собаки (порт model/Dog.kt)

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    var id: String { rawValue }
}

struct Dog: Identifiable, Equatable, Codable {
    var id: String
    var name: String
    var breed: String
    var birthDate: Date
    var weightKg: Double
    var gender: Gender
    var photoPath: String?
    // Свободный текст для персональных предупреждений справочника опасностей
    var allergies: String?
    var chronicConditions: String?
}

struct DogAge: Equatable {
    let years: Int
    let months: Int
}

// MARK: - Прогулки

struct Walk: Identifiable, Equatable, Codable {
    var id: String
    var dogId: String
    var startedAt: Date
    var durationSeconds: Int
    var note: String
}

// MARK: - Прививки

struct Vaccine: Identifiable, Equatable, Codable {
    var id: String
    var dogId: String
    var name: String
    var dateGiven: Date
    var nextDueDate: Date?
}

// MARK: - Напоминания

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case medication
    case feeding
    var id: String { rawValue }
}

struct Reminder: Identifiable, Equatable, Codable {
    var id: String
    var dogId: String
    var type: ReminderType
    var title: String
    // Часы и минуты срабатывания; дата-носитель — только контейнер времени
    var hour: Int
    var minute: Int
    // ISO-номера дней недели: 1 = понедельник … 7 = воскресенье
    var daysOfWeek: Set<Int>
    var isEnabled: Bool

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - Течка

struct HeatPeriod: Identifiable, Equatable, Codable {
    var id: String
    var dogId: String
    var startDate: Date
    var endDate: Date?
}

// MARK: - Настройки

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    var id: String { rawValue }
}
