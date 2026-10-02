import Foundation
import Combine

// MARK: - Центральное хранилище приложения
// Заменяет связку Room + репозиториев + use case'ов Android-версии: живые списки,
// сохранение в JSON при каждом изменении и синхронизация расписаний уведомлений.

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var dogs: [Dog] = []
    @Published private(set) var walks: [Walk] = []
    @Published private(set) var vaccines: [Vaccine] = []
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var heatPeriods: [HeatPeriod] = []

    let settings: SettingsStore

    let foods: [Food]
    let breedRisks: [BreedRisk]

    /// Активная собака приложения; nil — профиль ещё не создан или удалён
    var activeDog: Dog? {
        dogs.first { $0.id == settings.activeDogId }
    }

    func setActiveDog(_ dog: Dog?) {
        settings.activeDogId = dog?.id
    }

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        let guide = FoodGuideLoader.load()
        foods = guide.foods
        breedRisks = guide.breedRisks

        dogs = FileStore.load([Dog].self, fileName: "dogs.json")
        walks = FileStore.load([Walk].self, fileName: "walks.json")
        vaccines = FileStore.load([Vaccine].self, fileName: "vaccines.json")
        reminders = FileStore.load([Reminder].self, fileName: "reminders.json")
        heatPeriods = FileStore.load([HeatPeriod].self, fileName: "heat.json")

        // Активная собака удалена вне приложения — снимаем выбор
        if let activeDogId = settings.activeDogId, !dogs.contains(where: { $0.id == activeDogId }) {
            settings.activeDogId = nil
        }

        // Настройки живут отдельным ObservableObject; пересылаем его события,
        // чтобы все экраны, наблюдающие AppStore, реагировали на смену темы и пр.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []

    // MARK: Профиль собаки

    /// Добавляет собаку после валидации и делает её активной.
    func addDog(_ draft: DogProfileValidator.Draft) -> ValidationError? {
        let today = Date()
        if let error = DogProfileValidator.validate(draft, today: today) { return error }
        let dog = Dog(
            id: UUID().uuidString,
            name: draft.name.trimmingCharacters(in: .whitespaces),
            breed: draft.breed.trimmingCharacters(in: .whitespaces),
            birthDate: draft.birthDate ?? today,
            weightKg: draft.weightKg ?? 0,
            gender: draft.gender ?? .male,
            photoPath: draft.photoPath,
            allergies: draft.allergies?.trimmingCharacters(in: .whitespaces).nilIfBlank,
            chronicConditions: draft.chronicConditions?.trimmingCharacters(in: .whitespaces).nilIfBlank
        )
        dogs.append(dog)
        FileStore.save(dogs, fileName: "dogs.json")
        settings.activeDogId = dog.id
        return nil
    }

    func updateDog(id: String, _ draft: DogProfileValidator.Draft) -> ValidationError? {
        let today = Date()
        if let error = DogProfileValidator.validate(draft, today: today) { return error }
        guard let index = dogs.firstIndex(where: { $0.id == id }) else { return nil }
        var dog = dogs[index]
        dog.name = draft.name.trimmingCharacters(in: .whitespaces)
        dog.breed = draft.breed.trimmingCharacters(in: .whitespaces)
        dog.birthDate = draft.birthDate ?? dog.birthDate
        dog.weightKg = draft.weightKg ?? dog.weightKg
        dog.gender = draft.gender ?? dog.gender
        dog.photoPath = draft.photoPath
        dog.allergies = draft.allergies?.trimmingCharacters(in: .whitespaces).nilIfBlank
        dog.chronicConditions = draft.chronicConditions?.trimmingCharacters(in: .whitespaces).nilIfBlank
        dogs[index] = dog
        FileStore.save(dogs, fileName: "dogs.json")
        return nil
    }

    /// Обновляет только фото (тап по аватарке на экране профиля)
    func updateDogPhoto(id: String, photoPath: String) {
        guard let index = dogs.firstIndex(where: { $0.id == id }) else { return }
        dogs[index].photoPath = photoPath
        FileStore.save(dogs, fileName: "dogs.json")
    }

    /// Удаляет собаку и все её записи, переключая активный профиль на первую оставшуюся.
    func deleteDog(id: String) {
        reminders.filter { $0.dogId == id }.forEach { NotificationScheduler.cancelReminder(reminderId: $0.id) }
        vaccines.filter { $0.dogId == id }.forEach { NotificationScheduler.cancelVaccineReminder(vaccineId: $0.id) }

        dogs.removeAll { $0.id == id }
        walks.removeAll { $0.dogId == id }
        vaccines.removeAll { $0.dogId == id }
        reminders.removeAll { $0.dogId == id }
        heatPeriods.removeAll { $0.dogId == id }

        FileStore.save(dogs, fileName: "dogs.json")
        FileStore.save(walks, fileName: "walks.json")
        FileStore.save(vaccines, fileName: "vaccines.json")
        FileStore.save(reminders, fileName: "reminders.json")
        FileStore.save(heatPeriods, fileName: "heat.json")

        if settings.activeDogId == id {
            settings.activeDogId = dogs.first?.id
        }
    }

    // MARK: Прогулки

    @discardableResult
    func saveWalk(dogId: String, startedAt: Date, durationSeconds: Int, note: String) -> ValidationError? {
        // Прогулка слишком короткая для сохранения
        if durationSeconds <= 0 { return .invalidWalkDuration }
        let walk = Walk(
            id: UUID().uuidString,
            dogId: dogId,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        walks.append(walk)
        FileStore.save(walks, fileName: "walks.json")
        return nil
    }

    func deleteWalk(id: String) {
        walks.removeAll { $0.id == id }
        FileStore.save(walks, fileName: "walks.json")
    }

    func walks(forDog dogId: String) -> [Walk] {
        walks.filter { $0.dogId == dogId }.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: Прививки

    /// Сохраняет прививку и планирует push за 3 дня до следующей даты.
    @discardableResult
    func addVaccine(dogId: String, name: String, dateGiven: Date, nextDueDate: Date?) -> ValidationError? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return .emptyVaccineName }
        if let nextDueDate, nextDueDate.startOfDay < dateGiven.startOfDay { return .invalidVaccineDate }
        let vaccine = Vaccine(
            id: UUID().uuidString,
            dogId: dogId,
            name: name.trimmingCharacters(in: .whitespaces),
            dateGiven: dateGiven.startOfDay,
            nextDueDate: nextDueDate?.startOfDay
        )
        vaccines.append(vaccine)
        FileStore.save(vaccines, fileName: "vaccines.json")
        if let dog = dogs.first(where: { $0.id == dogId }) {
            NotificationScheduler.scheduleVaccineReminder(vaccine: vaccine, dogName: dog.name)
        }
        return nil
    }

    func deleteVaccine(id: String) {
        NotificationScheduler.cancelVaccineReminder(vaccineId: id)
        vaccines.removeAll { $0.id == id }
        FileStore.save(vaccines, fileName: "vaccines.json")
    }

    func vaccines(forDog dogId: String) -> [Vaccine] {
        vaccines.filter { $0.dogId == dogId }.sorted { $0.dateGiven > $1.dateGiven }
    }

    // MARK: Напоминания

    /// Сохраняет напоминание и, если оно включено, ставит расписание уведомлений.
    @discardableResult
    func addReminder(_ reminder: Reminder) -> ValidationError? {
        if reminder.title.trimmingCharacters(in: .whitespaces).isEmpty { return .emptyReminderTitle }
        if reminder.daysOfWeek.isEmpty { return .emptyReminderDays }
        var reminder = reminder
        reminder.id = UUID().uuidString
        reminders.append(reminder)
        FileStore.save(reminders, fileName: "reminders.json")
        if reminder.isEnabled, let dog = dogs.first(where: { $0.id == reminder.dogId }) {
            NotificationScheduler.schedule(reminder: reminder, dogName: dog.name)
        }
        return nil
    }

    /// Включает или выключает напоминание и синхронно ставит/снимает расписание.
    func setReminderEnabled(id: String, isEnabled: Bool) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].isEnabled = isEnabled
        FileStore.save(reminders, fileName: "reminders.json")
        if isEnabled, let dog = dogs.first(where: { $0.id == reminders[index].dogId }) {
            NotificationScheduler.schedule(reminder: reminders[index], dogName: dog.name)
        } else {
            NotificationScheduler.cancelReminder(reminderId: id)
        }
    }

    func deleteReminder(id: String) {
        NotificationScheduler.cancelReminder(reminderId: id)
        reminders.removeAll { $0.id == id }
        FileStore.save(reminders, fileName: "reminders.json")
    }

    func reminders(forDog dogId: String) -> [Reminder] {
        reminders.filter { $0.dogId == dogId }.sorted {
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            if $0.minute != $1.minute { return $0.minute < $1.minute }
            return $0.title < $1.title
        }
    }

    // MARK: Течка

    /// Сохраняет запись о течке с валидацией дат.
    @discardableResult
    func addHeatPeriod(dogId: String, startDate: Date, endDate: Date?) -> ValidationError? {
        if let error = HeatPeriodValidator.validate(startDate: startDate, endDate: endDate, today: Date()) {
            return error
        }
        let period = HeatPeriod(
            id: UUID().uuidString,
            dogId: dogId,
            startDate: startDate.startOfDay,
            endDate: endDate?.startOfDay
        )
        heatPeriods.append(period)
        FileStore.save(heatPeriods, fileName: "heat.json")
        return nil
    }

    func deleteHeatPeriod(id: String) {
        heatPeriods.removeAll { $0.id == id }
        FileStore.save(heatPeriods, fileName: "heat.json")
    }

    func heatPeriods(forDog dogId: String) -> [HeatPeriod] {
        heatPeriods.filter { $0.dogId == dogId }.sorted { $0.startDate > $1.startDate }
    }

    /// Все отмеченные дни всех течек активной собаки
    func heatDays(forDog dogId: String) -> Set<Date> {
        var days: Set<Date> = []
        for period in heatPeriods where period.dogId == dogId {
            let end = period.endDate ?? Date().startOfDay
            var cursor = period.startDate.startOfDay
            var guardCounter = 0
            while cursor <= end && guardCounter < 400 {
                days.insert(cursor)
                guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
                guardCounter += 1
            }
        }
        return days
    }

    // MARK: Поиск и персонализация

    func breedRisks(forFood foodId: String) -> [BreedRisk] {
        breedRisks.filter { $0.foodId == foodId }
    }

    func food(byId foodId: String) -> Food? {
        foods.first { $0.id == foodId }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
    }
}
