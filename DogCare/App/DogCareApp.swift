import SwiftUI

// Точка входа; порт MainActivity.kt + DogCareApplication.kt
@main
struct DogCareApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

// MARK: - Корневой экран: градиентный фон + панель вкладок (порт DogCareApp.kt)

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedTab: Tab = .profile

    enum Tab: Hashable {
        case profile, walks, vaccines, reminders, foods, settings
    }

    var body: some View {
        let dark = isDark
        GradientBackground {
            TabView(selection: $selectedTab) {
                ProfileTab()
                    .tabItem { Label(L("tab_profile"), systemImage: "pawprint.fill") }
                    .tag(Tab.profile)
                WalksTab()
                    .tabItem { Label(L("tab_walks"), systemImage: "figure.walk") }
                    .tag(Tab.walks)
                VaccinesTab()
                    .tabItem { Label(L("tab_vaccines"), systemImage: "cross.case.fill") }
                    .tag(Tab.vaccines)
                RemindersTab()
                    .tabItem { Label(L("tab_reminders"), systemImage: "bell.fill") }
                    .tag(Tab.reminders)
                FoodsTab()
                    .tabItem { Label(L("tab_food"), systemImage: "fork.knife") }
                    .tag(Tab.foods)
                SettingsTab()
                    .tabItem { Label(L("tab_settings"), systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
        }
        .preferredColorScheme(colorScheme)
        .environment(\.appColors, AppColorScheme.make(dark: dark))
    }

    // Маппинг ThemeMode: SYSTEM -> как в системе, LIGHT -> false, DARK -> true
    private var colorScheme: ColorScheme? {
        switch store.settings.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var isDark: Bool {
        colorScheme ?? (systemColorScheme == .dark)
    }
}
