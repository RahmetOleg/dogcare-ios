import SwiftUI

// MARK: - Заглушка пустого экрана (порт EmptyState.kt)

struct EmptyStateView: View {
    @Environment(\.appColors) private var colors
    let title: String
    var description: String? = nil
    var systemImage: String? = nil
    var action: (() -> AnyView)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(colors.onSurfaceVariant)
                Spacer().frame(height: 16)
            }
            Text(title)
                .font(.dcTitleMedium)
                .foregroundStyle(colors.onSurface)
                .multilineTextAlignment(.center)
            if let description {
                Spacer().frame(height: 8)
                Text(description)
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            if let action {
                Spacer().frame(height: 24)
                action()
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Карточка секции (порт SectionCard.kt)

struct SectionCard<Content: View>: View {
    @Environment(\.appColors) private var colors
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.dcTitleMedium)
                .foregroundStyle(colors.onSurface)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Круглый аватар собаки (порт DogAvatar.kt)

struct DogAvatar: View {
    @Environment(\.appColors) private var colors
    let photoPath: String?
    var contentDescription: String? = nil
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            if let data = DogPhotoStorage.loadImage(at: photoPath),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // При отсутствии фото — плейсхолдер с лапкой
                colors.primaryContainer
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(colors.onPrimaryContainer)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(Text(contentDescription ?? ""))
    }
}

// MARK: - Диалог подтверждения (порт ConfirmDialog.kt)

struct ConfirmDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmText: String
    var destructive: Bool = true
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(confirmText, role: destructive ? .destructive : nil, action: onConfirm)
            Button(L("action_cancel"), role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

extension View {
    func confirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmText: String,
        destructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            ConfirmDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmText: confirmText,
                destructive: destructive,
                onConfirm: onConfirm
            )
        )
    }
}

// MARK: - Чипы с переносом (замена Compose FlowRow)
// Adaptive-сетка сама переносит чипы на следующую строку, когда они не помещаются.

struct ChipFlow<Content: View>: View {
    var spacing: CGFloat = 8
    var chipMinimumWidth: CGFloat = 52
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: chipMinimumWidth), spacing: spacing)],
            alignment: .leading,
            spacing: 8
        ) {
            content()
        }
    }
}

// MARK: - Фильтр-чип (аналог Material3 FilterChip)

struct FilterChipView: View {
    @Environment(\.appColors) private var colors
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.dcLabelLarge)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? colors.primary : colors.surfaceVariant)
                .foregroundStyle(isSelected ? colors.onPrimary : colors.onSurfaceVariant)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Выбор дней недели (порт WeekdaySelector.kt)
// Чипы в переносе; дни в порядке понедельник..воскресенье

struct WeekdaySelector: View {
    let selectedDays: Set<Int>
    let onSelectionChange: (Set<Int>) -> Void

    private static let weekdays = [1, 2, 3, 4, 5, 6, 7] // ISO: 1 = понедельник

    var body: some View {
        ChipFlow {
            ForEach(Self.weekdays, id: \.self) { day in
                FilterChipView(
                    text: Formatters.weekdayShort(isoWeekday: day),
                    isSelected: selectedDays.contains(day)
                ) {
                    var updated = selectedDays
                    if selectedDays.contains(day) {
                        updated.remove(day)
                    } else {
                        updated.insert(day)
                    }
                    onSelectionChange(updated)
                }
            }
        }
    }
}

// MARK: - Поле с датой (порт DateField.kt)
// Ввод только через системный календарь, клавиатура отключена.

struct DateFieldRow: View {
    @Environment(\.appColors) private var colors
    let label: String
    let value: Date?
    let onValueChange: (Date) -> Void
    var minimumDate: Date? = nil
    var maximumDate: Date? = nil

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(value.map { Formatters.formatDate($0) } ?? "—")
                        .font(.dcBodyLarge)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .padding(12)
                .background(colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            DatePickerSheet(
                initialDate: value ?? Date(),
                minimumDate: minimumDate,
                maximumDate: maximumDate
            ) { date in
                onValueChange(date)
                showPicker = false
            }
        }
    }
}

// Лист выбора даты: системный DatePicker + кнопки ОК/Отмена
struct DatePickerSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    let minimumDate: Date?
    let maximumDate: Date?
    let onConfirm: (Date) -> Void

    init(initialDate: Date, minimumDate: Date?, maximumDate: Date?, onConfirm: @escaping (Date) -> Void) {
        _date = State(initialValue: initialDate)
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $date,
                in: closedRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action_ok")) { onConfirm(date.startOfDay) }
                }
            }
            .navigationTitle("")
        }
        .presentationDetents([.medium, .large])
    }

    private var closedRange: ClosedRange<Date> {
        let lower = minimumDate?.startOfDay ?? Date.distantPast.startOfDay
        let upper = maximumDate?.startOfDay ?? Date.distantFuture.startOfDay
        return min(lower, upper)...max(lower, upper)
    }
}

// MARK: - Поле со временем (порт TimeField.kt)

struct TimeFieldRow: View {
    @Environment(\.appColors) private var colors
    let label: String
    let value: Date?
    let onValueChange: (Date) -> Void

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(value.map { Formatters.formatTime($0) } ?? "—")
                        .font(.dcBodyLarge)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    Image(systemName: "clock")
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .padding(12)
                .background(colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            TimePickerSheet(initialDate: value ?? Date()) { date in
                onValueChange(date)
                showPicker = false
            }
        }
    }
}

struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    let onConfirm: (Date) -> Void

    init(initialDate: Date, onConfirm: @escaping (Date) -> Void) {
        _time = State(initialValue: initialDate)
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action_ok")) {
                        onConfirm(time)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
