import Foundation

// MARK: - Хранилище данных (замена Room/DAO на JSON-файлы)
// Каждый список хранится отдельным файлом в Application Support; даты — ISO-8601.

private extension JSONEncoder {
    static var shared: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var shared: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum PersistenceError: LocalizedError {
    case encode(Error)
    case write(Error)

    var errorDescription: String? {
        switch self {
        case .encode(let error): return "encode: \(error.localizedDescription)"
        case .write(let error): return "write: \(error.localizedDescription)"
        }
    }
}

enum FileStore {
    /// Каталог данных приложения; создаётся по требованию
    static var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("DogCare", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Загружает список из файла; отсутствующий или повреждённый файл даёт пустой список
    static func load<T: Codable>(_ type: [T].Type, fileName: String) -> [T] {
        let url = dataDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder.shared.decode([T].self, from: data)) ?? []
    }

    @discardableResult
    static func save<T: Codable>(_ items: [T], fileName: String) -> Result<Void, Error> {
        do {
            let data = try JSONEncoder.shared.encode(items)
            let url = dataDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return .success(())
        } catch {
            return .failure(PersistenceError.write(error))
        }
    }
}

// MARK: - Фото собаки (порт DogPhotoStorage.kt)

enum DogPhotoStorage {
    private static var photosDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Копирует данные выбранного фото в собственное хранилище приложения
    static func save(_ data: Data) -> String? {
        let target = photosDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: target, options: .atomic)
            return target.path
        } catch {
            return nil
        }
    }

    static func loadImage(at path: String?) -> Data? {
        guard let path, !path.isEmpty else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }
}

// MARK: - Настройки (замена DataStore на UserDefaults)

final class SettingsStore: ObservableObject {
    private enum Key {
        static let themeMode = "theme_mode"
        static let activeDogId = "active_dog_id"
        static let foodSearchHistory = "food_search_history"
        static let emergencyVetPhone = "emergency_vet_phone"
    }

    // История поиска хранится одной строкой с разделителем; порядок — от свежих к старым
    private static let historySeparator = "\u{1F}"
    private static let historyMaxEntries = 10

    private let defaults: UserDefaults

    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Key.themeMode) }
    }

    @Published var activeDogId: String? {
        didSet {
            if let activeDogId {
                defaults.set(activeDogId, forKey: Key.activeDogId)
            } else {
                defaults.removeObject(forKey: Key.activeDogId)
            }
        }
    }

    @Published var foodSearchHistory: [String] {
        didSet { defaults.set(foodSearchHistory.joined(separator: Self.historySeparator), forKey: Key.foodSearchHistory) }
    }

    @Published var emergencyVetPhone: String {
        didSet { defaults.set(emergencyVetPhone, forKey: Key.emergencyVetPhone) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawTheme = defaults.string(forKey: Key.themeMode)
        themeMode = rawTheme.flatMap(ThemeMode.init(rawValue:)) ?? .system
        activeDogId = defaults.string(forKey: Key.activeDogId)
        foodSearchHistory = defaults.string(forKey: Key.foodSearchHistory)?
            .components(separatedBy: Self.historySeparator)
            .filter { !$0.isBlank } ?? []
        emergencyVetPhone = defaults.string(forKey: Key.emergencyVetPhone) ?? ""
    }

    func setThemeMode(_ mode: ThemeMode) { themeMode = mode }
    func setActiveDogId(_ dogId: String?) { activeDogId = dogId }

    /// Дубликат поднимается наверх, старые записи вытесняются за пределы лимита
    func addFoodSearchQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let existing = foodSearchHistory.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        foodSearchHistory = ([trimmed] + existing).prefix(Self.historyMaxEntries).map { $0 }
    }

    func clearFoodSearchHistory() { foodSearchHistory = [] }

    func setEmergencyVetPhone(_ phone: String?) {
        emergencyVetPhone = (phone?.trimmingCharacters(in: .whitespaces) ?? "").isEmpty ? "" : phone!.trimmingCharacters(in: .whitespaces)
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty }
}
