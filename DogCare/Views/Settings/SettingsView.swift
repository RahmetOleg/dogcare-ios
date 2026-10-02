import SwiftUI
import UIKit

// Экран настроек; порт SettingsScreen.kt + SettingsViewModel.kt
struct SettingsTab: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors

    @State private var isExporting = false
    @State private var shareURL: URL?
    @State private var showExportError = false
    @State private var showHeat = false
    @State private var stubType: StubType?
    @State private var showStub = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    themeSection
                    dataSection
                    healthSection
                    comingSoonSection
                }
                .padding(16)
            }
            .navigationTitle(L("settings_title"))
            .navigationDestination(isPresented: $showHeat) {
                HeatView()
                    .toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(isPresented: $showStub) {
                if let stubType {
                    StubView(type: stubType)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .alert(
                L("error_export"),
                isPresented: $showExportError
            ) {
                Button(L("action_ok"), role: .cancel) {}
            }
        }
    }

    // MARK: Тема

    private var themeSection: some View {
        SectionCard(title: L("settings_theme_title")) {
            VStack(spacing: 4) {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        store.settings.setThemeMode(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: store.settings.themeMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(store.settings.themeMode == mode ? colors.primary : colors.onSurfaceVariant)
                            Text(themeLabel(mode))
                                .font(.dcBodyLarge)
                                .foregroundStyle(colors.onSurface)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func themeLabel(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: return L("settings_theme_system")
        case .light: return L("settings_theme_light")
        case .dark: return L("settings_theme_dark")
        }
    }

    // MARK: Данные

    private var dataSection: some View {
        SectionCard(title: L("settings_data_title")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("settings_export_hint"))
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)

                Button {
                    export()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                        } else {
                            Text(L("settings_export"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
    }

    private func export() {
        isExporting = true
        // Экспорт лёгкий, но сохраняем ощущение операции, как в Android-версии
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if let url = DataExporter.export(from: store) {
                shareURL = url
            } else {
                showExportError = true
            }
            isExporting = false
        }
    }

    // MARK: Здоровье

    // Календарь течки — полноценный экран; остальное — заглушки V2
    private var healthSection: some View {
        SectionCard(title: L("settings_health_title")) {
            rowButton(
                systemImage: "calendar",
                text: L("heat_calendar")
            ) {
                showHeat = true
            }
        }
    }

    // MARK: Скоро (V2-функционал)

    private var comingSoonSection: some View {
        SectionCard(title: L("settings_coming_soon")) {
            VStack(spacing: 4) {
                rowButton(systemImage: "location.fill", text: L("stub_gps")) {
                    stubType = .gpsTracker
                    showStub = true
                }
                rowButton(systemImage: "number.circle.fill", text: L("stub_food_calc")) {
                    stubType = .foodCalculator
                    showStub = true
                }
                rowButton(systemImage: "person.2.fill", text: L("stub_multi_profile")) {
                    stubType = .multiProfile
                    showStub = true
                }
            }
        }
    }

    private func rowButton(systemImage: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(colors.onSurfaceVariant)
                Text(text)
                    .font(.dcBodyLarge)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Системный share-шит для экспорта

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Заглушка V2-функционала; порт StubScreen.kt

enum StubType: String, Hashable, Identifiable {
    case gpsTracker
    case foodCalculator
    case multiProfile
    var id: String { rawValue }
}

struct StubView: View {
    @Environment(\.appColors) private var colors
    let type: StubType

    var body: some View {
        EmptyStateView(
            title: L("stub_title"),
            description: L("stub_description"),
            systemImage: "wrench.and.screwdriver.fill"
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch type {
        case .gpsTracker: return L("stub_gps_title")
        case .foodCalculator: return L("stub_food_calc_title")
        case .multiProfile: return L("stub_multi_profile_title")
        }
    }
}
