import Foundation

// MARK: - Калькулятор лакомств (порт TreatPortionCalculator.kt)

// Фактор активности для оценки суточной калорийности (MER/RER)
enum ActivityFactor: String, CaseIterable, Identifiable {
    case neuteredAdult
    case intactAdult
    case weightLoss
    case puppy4to12Months

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .neuteredAdult: return 1.6
        case .intactAdult: return 1.8
        case .weightLoss: return 1.0
        case .puppy4to12Months: return 2.0
        }
    }
}

struct TreatPortion: Equatable {
    let dailyKcal: Int
    let treatKcal: Int
    // Граммы лакомства в день, округление вниз до 0.1 г
    let grams: Double
}

// Правило «лакомства — не более 10% суточной калорийности»:
// RER = 70 * вес^0.75, MER = RER * фактор, лакомство = MER * 10%.
enum TreatPortionCalculator {
    static let treatMaxCaloriePercent = 10

    static func calculate(
        weightKg: Double,
        kcalPer100g: Double,
        factor: ActivityFactor,
        maxCaloriePercent: Int = treatMaxCaloriePercent
    ) -> TreatPortion? {
        if weightKg <= 0 || weightKg > 200 { return nil }
        if kcalPer100g <= 0 { return nil }
        if maxCaloriePercent <= 0 || maxCaloriePercent > 100 { return nil }

        let rer = 70.0 * pow(weightKg, 0.75)
        let dailyKcal = rer * factor.multiplier
        let treatKcal = dailyKcal * Double(maxCaloriePercent) / 100.0
        let grams = floor(treatKcal / (kcalPer100g / 100.0) * 10.0) / 10.0
        return TreatPortion(
            dailyKcal: Int(dailyKcal.rounded()),
            treatKcal: Int(treatKcal.rounded()),
            grams: grams
        )
    }
}

// MARK: - Валидация профиля (порт DogProfileValidator.kt)

enum ValidationError: Equatable {
    case emptyName
    case emptyBreed
    case genderNotSelected
    case invalidBirthDate
    case invalidWeight
    case emptyVaccineName
    case invalidVaccineDate
    case emptyReminderTitle
    case emptyReminderDays
    case invalidWalkDuration
    case invalidHeatPeriod
}

enum DogProfileValidator {
    static let maxWeightKg = 200.0

    /// Черновик формы профиля: незаполненное поле = nil
    struct Draft {
        var name: String = ""
        var breed: String = ""
        var birthDate: Date?
        var weightKg: Double?
        var gender: Gender?
        var photoPath: String?
        var allergies: String?
        var chronicConditions: String?
    }

    static func validate(_ draft: Draft, today: Date) -> ValidationError? {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { return .emptyName }
        if draft.breed.trimmingCharacters(in: .whitespaces).isEmpty { return .emptyBreed }
        guard let gender = draft.gender else { return .genderNotSelected }
        guard let birthDate = draft.birthDate, birthDate.startOfDay <= today.startOfDay else {
            return .invalidBirthDate
        }
        guard let weightKg = draft.weightKg, weightKg > 0, weightKg <= maxWeightKg else {
            return .invalidWeight
        }
        _ = gender
        return nil
    }
}

// MARK: - Прогноз течки (порт PredictNextHeatUseCase.kt)

enum HeatPrediction {
    private static let minCycleDays = 60
    private static let maxCycleDays = 400
    private static let defaultCycleDays = 180

    /// Прогноз следующей течки по истории начал: средний интервал между соседними
    /// началами (нормальный цикл 60–400 дней), иначе базовые 180 дней.
    static func predictNext(periods: [HeatPeriod], today: Date) -> Date? {
        guard !periods.isEmpty else { return nil }
        let starts = periods.map { $0.startDate.startOfDay }.sorted()
        var gaps: [Int] = []
        for index in 1..<starts.count {
            let days = Calendar.current.dateComponents(
                [.day],
                from: starts[index - 1],
                to: starts[index]
            ).day ?? 0
            if days >= minCycleDays && days <= maxCycleDays { gaps.append(days) }
        }
        let cycleDays: Int
        if gaps.isEmpty {
            cycleDays = defaultCycleDays
        } else {
            let average = Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())
            cycleDays = min(max(average, minCycleDays), maxCycleDays)
        }
        return Calendar.current.date(byAdding: .day, value: cycleDays, to: starts.last!)
    }
}

// MARK: - Валидация записи о течке (порт AddHeatPeriodUseCase.kt)

enum HeatPeriodValidator {
    /// Первый день обязателен, последний не раньше первого, даты не в будущем.
    static func validate(startDate: Date?, endDate: Date?, today: Date) -> ValidationError? {
        guard let start = startDate?.startOfDay, start <= today.startOfDay else { return .invalidHeatPeriod }
        if let end = endDate?.startOfDay {
            if end < start || end > today.startOfDay { return .invalidHeatPeriod }
        }
        return nil
    }
}
