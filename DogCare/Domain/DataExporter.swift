import Foundation

// MARK: - Экспорт данных в JSON (порт JsonDataExporter.kt + ExportDtos.kt)
// DTO намеренно повторяют структуру экспорта Android-версии: файл читается в обеих программах.
// Даты — строки ISO-8601, чтобы файл читался вне приложения.

struct DogExportDTO: Codable {
    let id: String
    let name: String
    let breed: String
    let birthDate: String
    let weightKg: Double
    let gender: String
    let photoPath: String?
}

struct VaccineExportDTO: Codable {
    let id: String
    let dogId: String
    let name: String
    let dateGiven: String
    let nextDueDate: String?
}

struct WalkExportDTO: Codable {
    let id: String
    let dogId: String
    let startedAt: String
    let durationSeconds: Int
    let note: String
}

struct ReminderExportDTO: Codable {
    let id: String
    let dogId: String
    let type: String
    let title: String
    let time: String
    let daysOfWeek: [Int]
    let isEnabled: Bool
}

struct DogCareExport: Codable {
    let exportedAt: String
    let dogs: [DogExportDTO]
    let vaccines: [VaccineExportDTO]
    let walks: [WalkExportDTO]
    let reminders: [ReminderExportDTO]
}

enum DataExporter {
    /// Пишет все данные в JSON во временном каталоге; URL возвращается для системного share-шита.
    /// Читает состояние AppStore, поэтому вызывается только с главного актора.
    @MainActor
    static func export(from store: AppStore) -> URL? {
        let isoFormatter = ISO8601DateFormatter()
        let dogs = store.dogs
        let export = DogCareExport(
            exportedAt: isoFormatter.string(from: Date()),
            dogs: dogs.map { dog in
                DogExportDTO(
                    id: dog.id,
                    name: dog.name,
                    breed: dog.breed,
                    birthDate: isoDate(dayOnly: dog.birthDate),
                    weightKg: dog.weightKg,
                    gender: dog.gender.rawValue.uppercased(),
                    photoPath: dog.photoPath
                )
            },
            vaccines: store.vaccines.map { vaccine in
                VaccineExportDTO(
                    id: vaccine.id,
                    dogId: vaccine.dogId,
                    name: vaccine.name,
                    dateGiven: isoDate(dayOnly: vaccine.dateGiven),
                    nextDueDate: vaccine.nextDueDate.map { isoDate(dayOnly: $0) }
                )
            },
            walks: store.walks.map { walk in
                WalkExportDTO(
                    id: walk.id,
                    dogId: walk.dogId,
                    startedAt: isoFormatter.string(from: walk.startedAt),
                    durationSeconds: walk.durationSeconds,
                    note: walk.note
                )
            },
            reminders: store.reminders.map { reminder in
                ReminderExportDTO(
                    id: reminder.id,
                    dogId: reminder.dogId,
                    type: reminder.type.rawValue.uppercased(),
                    title: reminder.title,
                    time: reminder.timeText,
                    daysOfWeek: reminder.daysOfWeek.sorted(),
                    isEnabled: reminder.isEnabled
                )
            }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(export)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("dogcare_export_\(formatter.string(from: Date())).json")
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func isoDate(dayOnly date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
