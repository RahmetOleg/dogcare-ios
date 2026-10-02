import SwiftUI

// Календарь течки; порт HeatScreen.kt + HeatViewModel.kt
struct HeatView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors

    // Месяц сетки; первый день месяца — носитель месяца
    @State private var month: Date = Date().startOfMonth
    @State private var pendingDeleteId: String?
    @State private var showAddDialog = false
    @State private var dialogStart: Date?
    @State private var dialogEnd: Date?
    @State private var dialogError: ValidationError?

    private var hasDog: Bool { store.activeDog != nil }

    private var periods: [HeatPeriod] {
        store.heatPeriods(forDog: store.activeDog?.id ?? "")
    }

    private var heatDays: Set<Date> {
        store.heatDays(forDog: store.activeDog?.id ?? "")
    }

    private var predictedNext: Date? {
        HeatPrediction.predictNext(periods: periods, today: Date())
    }

    var body: some View {
        Group {
            if !hasDog {
                EmptyStateView(
                    title: L("heat_no_dog_title"),
                    description: L("heat_no_dog_description"),
                    systemImage: "pawprint"
                )
            } else {
                heatContent
            }
        }
        .navigationTitle(L("heat_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasDog {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dialogStart = nil
                        dialogEnd = nil
                        dialogError = nil
                        showAddDialog = true
                    } label: {
                        Label(L("heat_add_title"), systemImage: "plus")
                    }
                }
            }
        }
        .confirmDialog(
            isPresented: Binding(
                get: { pendingDeleteId != nil },
                set: { if !$0 { pendingDeleteId = nil } }
            ),
            title: L("heat_delete_title"),
            message: L("heat_delete_message"),
            confirmText: L("action_delete"),
            onConfirm: {
                if let id = pendingDeleteId { store.deleteHeatPeriod(id: id) }
                pendingDeleteId = nil
            }
        )
        .sheet(isPresented: $showAddDialog) {
            addDialog
        }
    }

    private var heatContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                monthHeader
                weekdaysRow
                monthGrid

                // Прогноз по истории начал; обводкой отмечен на сетке
                if let predicted = predictedNext {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundStyle(colors.primary)
                        Text(L("heat_predicted", Formatters.formatDate(predicted)))
                            .font(.dcBodyLarge)
                            .foregroundStyle(colors.onSurface)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text(L("heat_history"))
                    .font(.dcTitleMedium)
                    .foregroundStyle(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let history = periods
                if history.isEmpty {
                    Text(L("heat_empty_history"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(history) { period in
                        HeatPeriodItemView(
                            period: period,
                            onDelete: { pendingDeleteId = period.id }
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: Сетка месяца (недели начинаются с понедельника)

    private var monthHeader: some View {
        HStack {
            Button {
                if let previous = Calendar.current.date(byAdding: .month, value: -1, to: month) {
                    month = previous.startOfMonth
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text(L("heat_prev_month")))

            Text(Formatters.formatMonthYear(month))
                .font(.dcTitleMedium)
                .frame(maxWidth: .infinity)

            Button {
                if let next = Calendar.current.date(byAdding: .month, value: 1, to: month) {
                    month = next.startOfMonth
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text(L("heat_next_month")))
        }
        .foregroundStyle(colors.onSurface)
    }

    private var weekdaysRow: some View {
        // 1 = понедельник … 7 = воскресенье
        HStack(spacing: 0) {
            ForEach([1, 2, 3, 4, 5, 6, 7], id: \.self) { day in
                Text(Formatters.weekdayShort(isoWeekday: day))
                    .font(.dcLabelMedium)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let today = Date().startOfDay
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
        // Смещение первого дня: понедельник — 0 пустых ячеек
        let firstWeekday = month.weekdayISO
        let leading = firstWeekday - 1
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in 1...daysInMonth {
            cells.append(Calendar.current.date(byAdding: .day, value: day - 1, to: month))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }

        return VStack(spacing: 6) {
            ForEach(0..<(cells.count / 7), id: \.self) { weekIndex in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let date = cells[weekIndex * 7 + dayIndex]
                        DayCellView(
                            date: date,
                            isHeat: date.map { heatDays.contains($0.startOfDay) } ?? false,
                            isToday: date == today,
                            isPredicted: date.map { $0 == predictedNext && $0 > today } ?? false
                        )
                    }
                }
            }
        }
    }

    // MARK: Диалог новой записи

    private var addDialog: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DateFieldRow(
                        label: L("heat_start_label"),
                        value: dialogStart,
                        onValueChange: { date in
                            dialogStart = date
                            dialogError = nil
                        },
                        maximumDate: Date()
                    )
                    DateFieldRow(
                        label: L("heat_end_label"),
                        value: dialogEnd,
                        onValueChange: { date in
                            dialogEnd = date
                            dialogError = nil
                        },
                        minimumDate: dialogStart
                    )
                    if dialogError == .invalidHeatPeriod {
                        Text(L("error_heat_period"))
                            .font(.dcBodyMedium)
                            .foregroundStyle(colors.error)
                    }
                }
                .padding(16)
            }
            .navigationTitle(L("heat_add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action_cancel")) { showAddDialog = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action_save")) { save() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let start = dialogStart else {
            dialogError = .invalidHeatPeriod
            return
        }
        guard let dogId = store.activeDog?.id else {
            showAddDialog = false
            return
        }
        if store.addHeatPeriod(dogId: dogId, startDate: start.startOfDay, endDate: dialogEnd?.startOfDay) == nil {
            showAddDialog = false
        } else {
            dialogError = .invalidHeatPeriod
        }
    }
}

// MARK: - Ячейка дня сетки
// Течка — залитый круг, прогноз — акцентная обводка (приоритетнее), сегодня — контур

private struct DayCellView: View {
    @Environment(\.appColors) private var colors
    let date: Date?
    let isHeat: Bool
    let isToday: Bool
    let isPredicted: Bool

    var body: some View {
        ZStack {
            if let date {
                Circle()
                    .fill(isHeat ? colors.primary : .clear)
                    .overlay(
                        Circle().stroke(
                            isPredicted
                                ? colors.primary
                                : (isToday && !isHeat ? colors.outline : .clear),
                            lineWidth: isPredicted ? 1.5 : 1
                        )
                    )
                    .frame(width: 32, height: 32)
                Text(String(Calendar.current.component(.day, from: date)))
                    .font(.dcLabelLarge)
                    .foregroundStyle(isHeat ? colors.onPrimary : colors.onSurface)
            }
        }
        .frame(height: 38)
    }
}

// MARK: - Элемент истории течек

private struct HeatPeriodItemView: View {
    @Environment(\.appColors) private var colors
    let period: HeatPeriod
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .foregroundStyle(colors.primary)
            Text(title)
                .font(.dcTitleMedium)
                .foregroundStyle(colors.onSurface)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(colors.onSurfaceVariant)
            }
        }
        .padding(16)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var title: String {
        if let end = period.endDate {
            let days = period.startDate.daysSince(end) + 1
            return L(
                "heat_period_with_end",
                Formatters.formatDate(period.startDate),
                Formatters.formatDate(end),
                days
            )
        }
        return L("heat_ongoing", Formatters.formatDate(period.startDate))
    }
}
