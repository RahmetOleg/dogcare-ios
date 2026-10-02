import SwiftUI

// MARK: - Палитра (порт Color.kt)

extension Color {
    // Светлая схема
    static let dcPrimaryLight = Color(red: 0x8C / 255.0, green: 0x4E / 255.0, blue: 0x00 / 255.0)
    static let dcOnPrimaryLight = Color.white
    static let dcPrimaryContainerLight = Color(red: 0xFF / 255.0, green: 0xDC / 255.0, blue: 0xC4 / 255.0)
    static let dcOnPrimaryContainerLight = Color(red: 0x2D / 255.0, green: 0x16 / 255.0, blue: 0x00 / 255.0)
    static let dcSecondaryContainerLight = Color(red: 0xF9 / 255.0, green: 0xDF / 255.0, blue: 0xBF / 255.0)
    static let dcOnSecondaryContainerLight = Color(red: 0x27 / 255.0, green: 0x19 / 255.0, blue: 0x04 / 255.0)
    static let dcErrorLight = Color(red: 0xBA / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0)
    static let dcOnErrorLight = Color.white
    static let dcErrorContainerLight = Color(red: 0xFF / 255.0, green: 0xDA / 255.0, blue: 0xD6 / 255.0)
    static let dcOnErrorContainerLight = Color(red: 0x41 / 255.0, green: 0x00 / 255.0, blue: 0x02 / 255.0)
    static let dcBackgroundLight = Color(red: 0xFF / 255.0, green: 0xF8 / 255.0, blue: 0xF5 / 255.0)
    static let dcOnBackgroundLight = Color(red: 0x22 / 255.0, green: 0x1A / 255.0, blue: 0x14 / 255.0)
    static let dcSurfaceLight = Color(red: 0xFF / 255.0, green: 0xF8 / 255.0, blue: 0xF5 / 255.0)
    static let dcOnSurfaceLight = Color(red: 0x22 / 255.0, green: 0x1A / 255.0, blue: 0x14 / 255.0)
    static let dcSurfaceVariantLight = Color(red: 0xF3 / 255.0, green: 0xDF / 255.0, blue: 0xD1 / 255.0)
    static let dcOnSurfaceVariantLight = Color(red: 0x52 / 255.0, green: 0x44 / 255.0, blue: 0x3A / 255.0)
    static let dcOutlineLight = Color(red: 0x85 / 255.0, green: 0x74 / 255.0, blue: 0x69 / 255.0)

    // Тёмная схема
    static let dcPrimaryDark = Color(red: 0xFF / 255.0, green: 0xB7 / 255.0, blue: 0x7C / 255.0)
    static let dcOnPrimaryDark = Color(red: 0x4D / 255.0, green: 0x28 / 255.0, blue: 0x00 / 255.0)
    static let dcPrimaryContainerDark = Color(red: 0x6D / 255.0, green: 0x3A / 255.0, blue: 0x00 / 255.0)
    static let dcOnPrimaryContainerDark = Color(red: 0xFF / 255.0, green: 0xDC / 255.0, blue: 0xC4 / 255.0)
    static let dcSecondaryContainerDark = Color(red: 0x58 / 255.0, green: 0x44 / 255.0, blue: 0x30 / 255.0)
    static let dcOnSecondaryContainerDark = Color(red: 0xF9 / 255.0, green: 0xDF / 255.0, blue: 0xBF / 255.0)
    static let dcErrorDark = Color(red: 0xFF / 255.0, green: 0xB4 / 255.0, blue: 0xAB / 255.0)
    static let dcOnErrorDark = Color(red: 0x69 / 255.0, green: 0x00 / 255.0, blue: 0x05 / 255.0)
    static let dcErrorContainerDark = Color(red: 0x93 / 255.0, green: 0x00 / 255.0, blue: 0x0A / 255.0)
    static let dcOnErrorContainerDark = Color(red: 0xFF / 255.0, green: 0xDA / 255.0, blue: 0xD6 / 255.0)
    static let dcBackgroundDark = Color(red: 0x1A / 255.0, green: 0x12 / 255.0, blue: 0x0D / 255.0)
    static let dcOnBackgroundDark = Color(red: 0xF1 / 255.0, green: 0xDF / 255.0, blue: 0xD4 / 255.0)
    static let dcSurfaceDark = Color(red: 0x1A / 255.0, green: 0x12 / 255.0, blue: 0x0D / 255.0)
    static let dcOnSurfaceDark = Color(red: 0xF1 / 255.0, green: 0xDF / 255.0, blue: 0xD4 / 255.0)
    static let dcSurfaceVariantDark = Color(red: 0x52 / 255.0, green: 0x44 / 255.0, blue: 0x3A / 255.0)
    static let dcOnSurfaceVariantDark = Color(red: 0xD7 / 255.0, green: 0xC2 / 255.0, blue: 0xB4 / 255.0)
    static let dcOutlineDark = Color(red: 0x9F / 255.0, green: 0x8D / 255.0, blue: 0x80 / 255.0)
}

// MARK: - Семантические роли темы (аналог MaterialTheme.colorScheme)

struct AppColorScheme {
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color
    let error: Color
    let onError: Color
    let errorContainer: Color
    let onErrorContainer: Color
    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let surfaceVariant: Color
    let onSurfaceVariant: Color
    let outline: Color

    static func make(dark: Bool) -> AppColorScheme {
        if dark {
            return AppColorScheme(
                primary: .dcPrimaryDark,
                onPrimary: .dcOnPrimaryDark,
                primaryContainer: .dcPrimaryContainerDark,
                onPrimaryContainer: .dcOnPrimaryContainerDark,
                secondaryContainer: .dcSecondaryContainerDark,
                onSecondaryContainer: .dcOnSecondaryContainerDark,
                error: .dcErrorDark,
                onError: .dcOnErrorDark,
                errorContainer: .dcErrorContainerDark,
                onErrorContainer: .dcOnErrorContainerDark,
                background: .dcBackgroundDark,
                onBackground: .dcOnBackgroundDark,
                surface: .dcSurfaceDark,
                onSurface: .dcOnSurfaceDark,
                surfaceVariant: .dcSurfaceVariantDark,
                onSurfaceVariant: .dcOnSurfaceVariantDark,
                outline: .dcOutlineDark
            )
        }
        return AppColorScheme(
            primary: .dcPrimaryLight,
            onPrimary: .dcOnPrimaryLight,
            primaryContainer: .dcPrimaryContainerLight,
            onPrimaryContainer: .dcOnPrimaryContainerLight,
            secondaryContainer: .dcSecondaryContainerLight,
            onSecondaryContainer: .dcOnSecondaryContainerLight,
            error: .dcErrorLight,
            onError: .dcOnErrorLight,
            errorContainer: .dcErrorContainerLight,
            onErrorContainer: .dcOnErrorContainerLight,
            background: .dcBackgroundLight,
            onBackground: .dcOnBackgroundLight,
            surface: .dcSurfaceLight,
            onSurface: .dcOnSurfaceLight,
            surfaceVariant: .dcSurfaceVariantLight,
            onSurfaceVariant: .dcOnSurfaceVariantLight,
            outline: .dcOutlineLight
        )
    }
}

// Роли доступны во всех экранах через окружение
private struct AppColorSchemeKey: EnvironmentKey {
    static let defaultValue = AppColorScheme.make(dark: false)
}

extension EnvironmentValues {
    var appColors: AppColorScheme {
        get { self[AppColorSchemeKey.self] }
        set { self[AppColorSchemeKey.self] = newValue }
    }
}

// MARK: - Фон приложения (порт Background.kt)
// Светлая тема: тёплый персиково-кремовый градиент с зелёным акцентом внизу.
// Тёмная: глубокий градиент с тёплыми и зелёными тонами, без чёрного.

struct GradientBackground<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0x3A / 255.0, green: 0x24 / 255.0, blue: 0x17 / 255.0),
                        Color(red: 0x27 / 255.0, green: 0x1B / 255.0, blue: 0x13 / 255.0),
                        Color(red: 0x26 / 255.0, green: 0x33 / 255.0, blue: 0x1F / 255.0),
                    ]
                    : [
                        Color(red: 0xFF / 255.0, green: 0xDD / 255.0, blue: 0xB8 / 255.0),
                        Color(red: 0xFF / 255.0, green: 0xF2 / 255.0, blue: 0xE3 / 255.0),
                        Color(red: 0xE9 / 255.0, green: 0xF1 / 255.0, blue: 0xDA / 255.0),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            content()
        }
    }
}

// MARK: - Статусы справочника (порт FoodStatusVisuals.kt)
// Цвета статусов: green / yellow / orange / red / black.
// В тёмной теме пары инвертируются — контейнер темнее, текст светлее.

struct FoodStatusVisuals {
    let container: Color
    let onContainer: Color
    // Для emergency: чёрный чип с красной окантовкой, чтобы читался и в тёмной теме
    let outline: Color?

    static func visuals(for status: StatusLevel, dark: Bool) -> FoodStatusVisuals {
        switch status {
        case .safe:
            return dark
                ? FoodStatusVisuals(container: Color(red: 0x1B / 255, green: 0x5E / 255, blue: 0x20 / 255), onContainer: Color(red: 0xA5 / 255, green: 0xD6 / 255, blue: 0xA7 / 255), outline: nil)
                : FoodStatusVisuals(container: Color(red: 0xC8 / 255, green: 0xE6 / 255, blue: 0xC9 / 255), onContainer: Color(red: 0x1B / 255, green: 0x5E / 255, blue: 0x20 / 255), outline: nil)
        case .conditionallySafe:
            return dark
                ? FoodStatusVisuals(container: Color(red: 0x6D / 255, green: 0x53 / 255, blue: 0x00 / 255), onContainer: Color(red: 0xFF / 255, green: 0xE0 / 255, blue: 0x82 / 255), outline: nil)
                : FoodStatusVisuals(container: Color(red: 0xFF / 255, green: 0xF3 / 255, blue: 0xC4 / 255), onContainer: Color(red: 0x6D / 255, green: 0x53 / 255, blue: 0x00 / 255), outline: nil)
        case .dangerous:
            return dark
                ? FoodStatusVisuals(container: Color(red: 0xBF / 255, green: 0x36 / 255, blue: 0x0C / 255), onContainer: Color(red: 0xFF / 255, green: 0xCC / 255, blue: 0xBC / 255), outline: nil)
                : FoodStatusVisuals(container: Color(red: 0xFF / 255, green: 0xE0 / 255, blue: 0xB2 / 255), onContainer: Color(red: 0xBF / 255, green: 0x36 / 255, blue: 0x0C / 255), outline: nil)
        case .toxic:
            return dark
                ? FoodStatusVisuals(container: Color(red: 0xB7 / 255, green: 0x1C / 255, blue: 0x1C / 255), onContainer: Color(red: 0xFF / 255, green: 0xCD / 255, blue: 0xD2 / 255), outline: nil)
                : FoodStatusVisuals(container: Color(red: 0xFF / 255, green: 0xCD / 255, blue: 0xD2 / 255), onContainer: Color(red: 0xB7 / 255, green: 0x1C / 255, blue: 0x1C / 255), outline: nil)
        case .emergency:
            return dark
                ? FoodStatusVisuals(container: Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255), onContainer: .white, outline: Color(red: 0xB7 / 255, green: 0x1C / 255, blue: 0x1C / 255))
                : FoodStatusVisuals(container: Color(red: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255), onContainer: .white, outline: Color(red: 0xB7 / 255, green: 0x1C / 255, blue: 0x1C / 255))
        }
    }
}

extension StatusLevel {
    func visuals(dark: Bool) -> FoodStatusVisuals {
        FoodStatusVisuals.visuals(for: self, dark: dark)
    }

    var labelKey: String {
        switch self {
        case .safe: return "foods_status_safe"
        case .conditionallySafe: return "foods_status_conditionally"
        case .dangerous: return "foods_status_dangerous"
        case .toxic: return "foods_status_toxic"
        case .emergency: return "foods_status_emergency"
        }
    }
}

// MARK: - Шрифтовая система (порт Type.kt)

extension Font {
    static let dcHeadline = Font.system(size: 28, weight: .semibold)
    static let dcTitleLarge = Font.system(size: 22, weight: .semibold)
    static let dcTitleMedium = Font.system(size: 16, weight: .semibold)
    static let dcBodyLarge = Font.system(size: 16)
    static let dcBodyMedium = Font.system(size: 14)
    static let dcLabelLarge = Font.system(size: 14, weight: .medium)
    static let dcLabelMedium = Font.system(size: 12, weight: .medium)
    static let dcLabelSmall = Font.system(size: 11)
}
