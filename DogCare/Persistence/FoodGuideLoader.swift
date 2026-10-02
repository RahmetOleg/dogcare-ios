import Foundation

// MARK: - Загрузчик справочника из актива (порт FoodGuideSeeder.kt + FoodGuideRepository)

// DTO зеркалят структуру актива foods_guide.json; справочник загружается без изменений.
// Актив содержит записи в двух форматах: полный (toxic_agent/safe_form/danger_form/first_aid)
// и компактный (agent/safe/danger/aid) — оба поддержаны.
private struct FoodSeedDTO: Decodable {
    let id: String
    let name: String
    let aliases: [String]
    let status: String
    // Полный формат
    let toxicAgent: String?
    let safeForm: String?
    let dangerForm: [String]?
    let symptoms: [String]?
    let firstAid: String?
    let notes: String?
    // Компактный формат
    let agent: String?
    let safe: String?
    let danger: [String]?
    let aid: String?
}

private struct BreedRiskSeedDTO: Decodable {
    let breedId: String
    let foodId: String
    let risk: String
}

private struct GuideSeedDTO: Decodable {
    let foods: [FoodSeedDTO]
    let breedRisks: [BreedRiskSeedDTO]?
}

enum FoodGuideLoader {
    static func load() -> (foods: [Food], breedRisks: [BreedRisk]) {
        guard let url = Bundle.main.url(forResource: "foods_guide", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return ([], [])
        }
        return parse(data)
    }

    // BOM срезается: файл мог пройти через Windows-буфер обмена
    static func parse(_ data: Data) -> (foods: [Food], breedRisks: [BreedRisk]) {
        var cleaned = data
        if cleaned.count >= 3,
           cleaned[0] == 0xEF, cleaned[1] == 0xBB, cleaned[2] == 0xBF {
            cleaned = cleaned.dropFirst(3)
        }
        guard let seed = try? JSONDecoder().decode(GuideSeedDTO.self, from: cleaned) else {
            return ([], [])
        }
        let foods = seed.foods.map { food in
            Food(
                id: food.id,
                name: food.name,
                aliases: food.aliases,
                status: StatusLevel(rawValue: food.status) ?? .conditionallySafe,
                toxicAgent: food.toxicAgent ?? food.agent,
                safeForm: food.safeForm ?? food.safe,
                dangerForms: (food.dangerForm?.isEmpty == false ? food.dangerForm : food.danger) ?? [],
                symptoms: food.symptoms ?? [],
                firstAid: {
                    let full = food.firstAid ?? ""
                    return full.isEmpty ? (food.aid ?? "") : full
                }(),
                notes: food.notes ?? ""
            )
        }
        let breedRisks = (seed.breedRisks ?? []).map {
            BreedRisk(breedId: $0.breedId, foodId: $0.foodId, risk: $0.risk)
        }
        return (foods, breedRisks)
    }
}
