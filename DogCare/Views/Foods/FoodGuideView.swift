import SwiftUI

// Экран справочника опасных продуктов; порт FoodGuideScreen.kt + FoodGuideViewModel.kt
struct FoodsTab: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors
    @Environment(\.colorScheme) private var colorScheme

    @State private var query = ""
    @State private var path: [String] = [] // id продуктов

    private var results: [Food] {
        FoodSearchEngine.search(foods: store.foods, rawQuery: query)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 12) {
                DisclaimerBanner()

                searchField

                // История поиска видна только до ввода запроса
                if query.isEmpty && !store.settings.foodSearchHistory.isEmpty {
                    SearchHistoryRow { item in
                        query = item
                    }
                }

                if results.isEmpty {
                    EmptyStateView(
                        title: L("foods_empty_title"),
                        description: L("foods_empty_description")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(results) { food in
                                FoodListItem(food: food) {
                                    // Открытие карточки фиксируется в истории; пустой запрос не пишем
                                    store.settings.addFoodSearchQuery(query)
                                    path.append(food.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(.top, 8)
            .navigationTitle(L("foods_title"))
            .navigationDestination(for: String.self) { foodId in
                FoodCardView(foodId: foodId)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(colors.onSurfaceVariant)
            TextField(L("foods_search_hint"), text: $query)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .accessibilityLabel(Text(L("foods_clear_query")))
            }
        }
        .padding(12)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }
}

// MARK: - Баннер с дисклеймером

struct DisclaimerBanner: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundStyle(colors.onSurfaceVariant)
            Text(L("foods_disclaimer"))
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Строка истории поиска

private struct SearchHistoryRow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors
    let onPick: ((String) -> Void)?

    init(onPick: ((String) -> Void)? = nil) {
        self.onPick = onPick
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("foods_history"))
                    .font(.dcLabelLarge)
                    .foregroundStyle(colors.onSurfaceVariant)
                Spacer()
                Button(L("foods_clear_history")) {
                    store.settings.clearFoodSearchHistory()
                }
                .font(.dcLabelLarge)
            }
            .padding(.horizontal, 16)

            ChipFlow(chipMinimumWidth: 60) {
                ForEach(store.settings.foodSearchHistory, id: \.self) { item in
                    FilterChipView(text: item, isSelected: false) {
                        onPick?(item)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Элемент списка продуктов

private struct FoodListItem: View {
    @Environment(\.appColors) private var colors
    @Environment(\.colorScheme) private var colorScheme
    let food: Food
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                Circle()
                    .fill(food.status.visuals(dark: colorScheme == .dark).container)
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.dcTitleMedium)
                        .foregroundStyle(colors.onSurface)
                    Text(L(food.status.labelKey))
                        .font(.dcLabelMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                Spacer()
            }
            .padding(12)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
