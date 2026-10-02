import SwiftUI

// Карточка продукта справочника; порт FoodCardScreen.kt + FoodCardViewModel.kt
struct FoodCardView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    let foodId: String

    // Калькулятор: вес подставляется из профиля, калорийность и фактор вводит пользователь
    @State private var weightKg = ""
    @State private var kcalPer100g = ""
    @State private var factor: ActivityFactor = .neuteredAdult
    @State private var weightInitialized = false

    // Диалог экстренного звонка
    @State private var showCallDialog = false
    @State private var emergencyPhone = ""

    private var food: Food? { store.food(byId: foodId) }

    private var portion: TreatPortion? {
        let weight = weightKg.replacingOccurrences(of: ",", with: ".").toDouble
        let kcal = kcalPer100g.replacingOccurrences(of: ",", with: ".").toDouble
        guard let weight, let kcal else { return nil }
        return TreatPortionCalculator.calculate(weightKg: weight, kcalPer100g: kcal, factor: factor)
    }

    var body: some View {
        Group {
            if let food {
                content(food)
            } else {
                EmptyStateView(title: L("foods_not_found"), systemImage: "pawprint")
            }
        }
        .navigationTitle(L("foods_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !weightInitialized {
                weightInitialized = true
                if let dog = store.activeDog {
                    let rounded = (dog.weightKg * 10).rounded() / 10
                    if rounded.truncatingRemainder(dividingBy: 1) == 0 {
                        weightKg = String(Int(rounded))
                    } else {
                        weightKg = Formatters.formatWeight(rounded).replacingOccurrences(of: ",", with: ".")
                    }
                }
                emergencyPhone = store.settings.emergencyVetPhone
            }
        }
        .sheet(isPresented: $showCallDialog) {
            callDialog
        }
    }

    @ViewBuilder
    private func content(_ food: Food) -> some View {
        let visuals = food.status.visuals(dark: colorScheme == .dark)
        ScrollView {
            VStack(spacing: 12) {
                // Заголовок: статус цветом, токсичное вещество, дисклеймер
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(visuals.container)
                            .frame(width: 14, height: 14)
                        Text(L(food.status.labelKey))
                            .font(.dcLabelLarge)
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                    Text(food.name)
                        .font(.dcHeadline)
                        .foregroundStyle(colors.onSurface)
                    if let agent = food.toxicAgent {
                        Text(L("food_toxic_agent", agent))
                            .font(.dcBodyMedium)
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                    Text(L("foods_disclaimer"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Персональное предупреждение по аллергиям из профиля
                if let dog = store.activeDog,
                   let allergyText = dog.allergies,
                   AllergyMatcher.matches(allergyText, food: food) {
                    personalBanner(
                        title: L("food_allergy_warning", dog.name),
                        text: allergyText,
                        emphasized: true
                    )
                }

                // Хронические заболевания — напоминание без утверждений
                if let dog = store.activeDog, let chronicText = dog.chronicConditions {
                    personalBanner(
                        title: L("food_chronic_note"),
                        text: chronicText,
                        emphasized: false
                    )
                }

                SectionCard(title: L("food_block_safe")) {
                    Text(food.safeForm ?? L("food_no_safe_form"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurface)
                }

                SectionCard(title: L("food_block_danger")) {
                    BulletListView(items: food.dangerForms.isEmpty ? [L("food_no_data")] : food.dangerForms)
                }

                SectionCard(title: L("food_block_symptoms")) {
                    BulletListView(items: food.symptoms.isEmpty ? [L("food_no_data")] : food.symptoms)
                }

                SectionCard(title: L("food_block_first_aid")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.firstAid)
                            .font(.dcBodyMedium)
                            .foregroundStyle(colors.onSurface)
                        Text(food.notes)
                            .font(.dcBodyMedium)
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                }

                // Красная кнопка экстренного звонка
                Button {
                    showCallDialog = true
                } label: {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text(L("food_emergency_button"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.error)

                // Породные риски: только «осторожно», никогда не запрет
                let risks = store.breedRisks(forFood: foodId)
                if !risks.isEmpty {
                    breedRisksCard(risks)
                }

                // Калькулятор порции имеет смысл только для съедобного
                if food.status == .safe || food.status == .conditionallySafe {
                    treatCalculator
                }
            }
            .padding(16)
        }
    }

    private func breedRisksCard(_ risks: [BreedRisk]) -> some View {
        let ownBreedIds = BreedMatcher.matchBreedIds(store.activeDog?.breed)
        let hasOwnBreed = risks.contains { ownBreedIds.contains($0.breedId) }
        return SectionCard(title: L("food_block_breeds")) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(risks) { risk in
                    let isOwnBreed = ownBreedIds.contains(risk.breedId)
                    Text((isOwnBreed ? "⚠ " : "") + risk.risk)
                        .font(.dcBodyMedium)
                        .foregroundStyle(isOwnBreed ? colors.error : colors.onSurface)
                }
                if hasOwnBreed {
                    Text(L("food_breed_yours_note"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.error)
                }
            }
        }
    }

    private var treatCalculator: some View {
        SectionCard(title: L("foods_calc_title")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("foods_calc_hint"))
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)

                HStack(spacing: 12) {
                    CalculatorNumberField(title: L("foods_calc_weight"), text: $weightKg)
                    CalculatorNumberField(title: L("foods_calc_kcal"), text: $kcalPer100g)
                }

                // Фактор активности для оценки суточной нормы (RER/MER)
                ChipFlow(chipMinimumWidth: 80) {
                    ForEach(ActivityFactor.allCases) { item in
                        FilterChipView(
                            text: factorLabel(item),
                            isSelected: factor == item
                        ) {
                            factor = item
                        }
                    }
                }

                if let portion {
                    Text(
                        L(
                            "foods_calc_result",
                            Formatters.formatGrams(portion.grams),
                            portion.treatKcal,
                            portion.dailyKcal
                        )
                    )
                    .font(.dcTitleMedium)
                    .foregroundStyle(colors.onSurface)
                } else {
                    Text(L("foods_calc_invalid"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
            }
        }
    }

    private func factorLabel(_ factor: ActivityFactor) -> String {
        switch factor {
        case .neuteredAdult: return L("foods_factor_neutered")
        case .intactAdult: return L("foods_factor_intact")
        case .weightLoss: return L("foods_factor_weight_loss")
        case .puppy4to12Months: return L("foods_factor_puppy")
        }
    }

    @ViewBuilder
    private func personalBanner(title: String, text: String, emphasized: Bool) -> some View {
        let container = emphasized ? colors.errorContainer : colors.secondaryContainer
        let onContainer = emphasized ? colors.onErrorContainer : colors.onSecondaryContainer
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(onContainer)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dcTitleMedium)
                    .foregroundStyle(onContainer)
                Text(text)
                    .font(.dcBodyMedium)
                    .foregroundStyle(onContainer)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(container)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // Диалог экстренного звонка: номер сохраняется, следующий раз поле предзаполнено
    private var callDialog: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("food_emergency_hint"))
                    .font(.dcBodyMedium)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("food_emergency_phone_label"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                    TextField("", text: $emergencyPhone)
                        .keyboardType(.phonePad)
                        .padding(12)
                        .background(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
            }
            .padding(16)
            .navigationTitle(L("food_emergency_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action_cancel")) { showCallDialog = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("food_emergency_call")) {
                        // Оставляем только цифры и плюс
                        let phone = emergencyPhone.filter { $0.isNumber || $0 == "+" }
                        if !phone.isEmpty {
                            store.settings.emergencyVetPhone = phone
                        }
                        emergencyPhone = phone
                        showCallDialog = false
                        // Пустой номер тоже валиден: откроется набор без адресата
                        if let url = URL(string: "tel://" + phone) {
                            openURL(url)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Вспомогательные вью

struct BulletListView: View {
    @Environment(\.appColors) private var colors
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text("• " + item)
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurface)
            }
        }
    }
}

private struct CalculatorNumberField: View {
    @Environment(\.appColors) private var colors
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .padding(12)
                .background(colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private extension String {
    var toDouble: Double? {
        Double(self)
    }
}
