import Foundation

// Помощник локализации: все строки — через ключи Localizable.strings (en + ru),
// как в Android-версии (values + values-ru)
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}

// Русские склонения возраста через stringsdict (port plurals age_years / age_months)
func pluralString(_ key: String, _ count: Int) -> String {
    String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)
}

func ageText(years: Int, months: Int) -> String {
    let yearsPart: String? = years > 0 ? pluralString("age_years", years) : nil
    let monthsPart: String? = months > 0 ? pluralString("age_months", months) : nil
    switch (yearsPart, monthsPart) {
    case let (years?, months?):
        return L("age_combined", years, months)
    case let (years?, nil):
        return years
    case let (nil, months?):
        return months
    default:
        return L("age_under_month")
    }
}
