import Foundation

// MARK: - Латинизация кириллицы (порт Translit.kt)

private let ruToLatin: [Character: String] = [
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d",
    "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i",
    "й": "i", "к": "k", "л": "l", "м": "m", "н": "n",
    "о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
    "у": "u", "ф": "f", "х": "h", "ц": "c", "ч": "ch",
    "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "",
    "э": "e", "ю": "yu", "я": "ya",
]

func latinize(_ value: String) -> String {
    var result = ""
    for ch in value.lowercased() {
        result += ruToLatin[ch] ?? String(ch)
    }
    return result
}

// Нормализация для сравнения: нижний регистр, ё -> е, схлопнутые пробелы
func normalizeText(_ value: String) -> String {
    let lowered = value.lowercased().replacingOccurrences(of: "ё", with: "е")
    return lowered.trimmingCharacters(in: .whitespaces)
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

// MARK: - Поисковый движок справочника (порт FoodSearchEngine.kt)

enum FoodSearchEngine {
    private static let scoreExact = 1000
    private static let scorePrefix = 800
    private static let scoreSubstring = 600
    private static let scoreTokenExact = 500
    private static let scoreTokenPrefix = 300
    private static let scoreTokenSubstring = 200
    private static let scoreFuzzyBase = 150
    private static let scoreFuzzyStep = 10

    // Порог Levenshtein: короткие слова прощаем на 1, длинные — на 2
    private static func fuzzyThreshold(tokenLength: Int) -> Int { tokenLength <= 4 ? 1 : 2 }

    static func search(foods: [Food], rawQuery: String) -> [Food] {
        let query = normalizeText(rawQuery)
        if query.isEmpty {
            return foods.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }

        let queryVariants = variantsOf(query)
        let queryTokens = Set(
            queryVariants.flatMap { $0.split(separator: " ").map(String.init) }
                .filter { $0.count >= 2 }
        )

        var scored: [(food: Food, score: Int)] = []
        for food in foods {
            let score = scoreOf(food, queryVariants: queryVariants, queryTokens: queryTokens)
            if score > 0 { scored.append((food, score)) }
        }
        return scored
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.food.name.lowercased() < $1.food.name.lowercased()
            }
            .map { $0.food }
    }

    // Все варианты строки для сверки: как есть, латиницей
    private static func variantsOf(_ value: String) -> Set<String> {
        [value, latinize(value)]
    }

    private static func scoreOf(_ food: Food, queryVariants: Set<String>, queryTokens: Set<String>) -> Int {
        var best = 0
        let phrases = [food.name] + food.aliases
        let normalizedPhrases = phrases.map { normalizeText($0) }
        let phraseVariants = normalizedPhrases.flatMap { variantsOf($0) }

        // Сверка всей строки запроса с полными названиями и алиасами
        for queryVariant in queryVariants {
            for phraseVariant in phraseVariants {
                if phraseVariant == queryVariant {
                    best = max(best, scoreExact)
                } else if phraseVariant.hasPrefix(queryVariant) {
                    best = max(best, scorePrefix)
                } else if phraseVariant.contains(queryVariant) {
                    best = max(best, scoreSubstring)
                }
            }
        }

        // Токенная сверка: слова запроса против слов названий/алиасов (транслит включён)
        let foodTokens = Set(
            phraseVariants.flatMap { $0.split(separator: " ").map(String.init) }
                .filter { $0.count >= 2 }
        )
        for queryToken in queryTokens {
            for foodToken in foodTokens {
                if foodToken == queryToken {
                    best = max(best, scoreTokenExact)
                } else if foodToken.hasPrefix(queryToken) {
                    best = max(best, scoreTokenPrefix)
                } else if foodToken.contains(queryToken) {
                    best = max(best, scoreTokenSubstring)
                } else {
                    best = max(best, fuzzyScore(queryToken: queryToken, foodToken: foodToken))
                }
            }
        }
        return best
    }

    private static func fuzzyScore(queryToken: String, foodToken: String) -> Int {
        let threshold = fuzzyThreshold(tokenLength: queryToken.count)
        let distance = boundedLevenshtein(queryToken, foodToken, maxDistance: threshold)
        if distance >= 1 && distance <= threshold {
            return scoreFuzzyBase - distance * scoreFuzzyStep
        }
        return 0
    }

    // Levenshtein с отсечкой: расстояния выше maxDistance сразу дают maxDistance + 1
    private static func boundedLevenshtein(_ left: String, _ right: String, maxDistance: Int) -> Int {
        let a = Array(left), b = Array(right)
        if abs(a.count - b.count) > maxDistance { return maxDistance + 1 }
        var previous = Array(0...a.count)
        var current = [Int](repeating: 0, count: a.count + 1)
        for row in 1...b.count {
            current[0] = row
            var rowMin = row
            for column in 1...a.count {
                let substitution = previous[column - 1] + (a[column - 1] == b[row - 1] ? 0 : 1)
                current[column] = min(current[column - 1] + 1, previous[column] + 1, substitution)
                rowMin = min(rowMin, current[column])
            }
            if rowMin > maxDistance { return maxDistance + 1 }
            swap(&previous, &current)
        }
        return previous[a.count]
    }
}

// MARK: - Породные риски (порт Personalization.kt / BreedMatcher)

enum BreedMatcher {
    // Только породы, встречающиеся в breedRisks справочника
    private static let knownBreeds: [String: [String]] = [
        "chihuahua": ["чихуахуа", "chihuahua"],
        "yorkshire_terrier": ["йоркширский терьер", "йорк", "yorkshire terrier", "yorkie"],
        "pug": ["мопс", "pug"],
        "bulldog": ["бульдог", "bulldog"],
        "beagle": ["бигль", "beagle"],
        "labrador": ["лабрадор", "labrador"],
        "mini_schnauzer": ["цвергшнауцер", "миниатюрный шнауцер", "miniature schnauzer", "mini schnauzer"],
        "cocker_spaniel": ["кокер спаниель", "cocker spaniel", "спаниель"],
        "doberman": ["доберман", "doberman"],
        "golden_retriever": ["золотистый ретривер", "голден ретривер", "golden retriever", "ретривер"],
        "collie": ["колли", "collie"],
    ]

    /// Возвращает breedId пород, узнанных в свободном тексте породы из профиля.
    static func matchBreedIds(_ breedText: String?) -> Set<String> {
        guard let breedText, !breedText.isEmpty else { return [] }
        let normalized = normalizeText(breedText)
        if normalized.isEmpty { return [] }
        let latinized = latinize(normalized)
        var result: Set<String> = []
        for (breedId, keys) in knownBreeds {
            for key in keys {
                let keyNormalized = normalizeText(key)
                if normalized.contains(keyNormalized) || keyNormalized.contains(normalized) ||
                    latinized.contains(normalizeText(latinize(key))) {
                    result.insert(breedId)
                    break
                }
            }
        }
        return result
    }
}

// MARK: - Персональное предупреждение об аллергиях (порт AllergyMatcher)

enum AllergyMatcher {
    private static let minTokenLength = 3
    private static let prefixLength = 4
    private static let containmentLength = 5

    /// true, если в тексте аллергий упоминается этот продукт или его алиас.
    /// «У Рекса аллергия на курицу» сработает для «Курица (мясо)».
    static func matches(_ allergyText: String?, food: Food) -> Bool {
        guard let allergyText else { return false }
        let normalizedAllergy = normalizeText(allergyText)
        if normalizedAllergy.isEmpty { return false }
        let allergyLatin = latinize(normalizedAllergy)

        let foodPhrases = ([food.name] + food.aliases)
            .map { normalizeText($0) }
            .filter { $0.count >= minTokenLength }
        let foodPhrasesLatin = foodPhrases.map { latinize($0) }

        // Фраза целиком: «аллергия на куриное мясо» содержит «куриное мясо»
        for (phrase, phraseLatin) in zip(foodPhrases, foodPhrasesLatin) {
            if normalizedAllergy.contains(phrase) || allergyLatin.contains(phraseLatin) { return true }
            if phrase.contains(normalizedAllergy) && normalizedAllergy.count >= minTokenLength { return true }
        }

        // Токенный уровень: «курица, говядина» → токен «говядина»;
        // сравнение по общему префиксу, чтобы ловить падежи («на курицу»)
        let separators = CharacterSet(charactersIn: " ,;/")
        let allergyTokens = Set(
            (normalizedAllergy.components(separatedBy: separators) + allergyLatin.components(separatedBy: separators))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count >= minTokenLength }
        )
        let foodTokens = foodPhrases.flatMap { $0.components(separatedBy: " ") } +
            foodPhrasesLatin.flatMap { $0.components(separatedBy: " ") }
        return foodTokens.contains { foodToken in
            foodToken.count >= minTokenLength &&
                allergyTokens.contains { allergyToken in tokenMatch(foodToken, allergyToken) }
        }
    }

    // Совпадение токенов: точное, по общему префиксу (падежи) или вхождению
    private static func tokenMatch(_ foodToken: String, _ allergyToken: String) -> Bool {
        if foodToken == allergyToken { return true }
        if foodToken.count >= prefixLength && allergyToken.count >= prefixLength {
            if commonPrefixLength(foodToken, allergyToken) >= prefixLength { return true }
        }
        if foodToken.count >= containmentLength && allergyToken.contains(foodToken) { return true }
        return allergyToken.count >= containmentLength && foodToken.contains(allergyToken)
    }

    private static func commonPrefixLength(_ left: String, _ right: String) -> Int {
        var index = 0
        let a = Array(left), b = Array(right)
        let limit = min(a.count, b.count)
        while index < limit && a[index] == b[index] { index += 1 }
        return index
    }
}
