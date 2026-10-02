import SwiftUI

// Экран напоминаний (лекарства и кормление); порт ReminderListScreen.kt
struct RemindersTab: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors

    @State private var showAddForm = false
    @State private var pendingDeleteId: String?

    private var hasDog: Bool { store.activeDog != nil }

    var body: some View {
        NavigationStack {
            Group {
                if !hasDog {
                    EmptyStateView(
                        title: L("reminders_no_dog_title"),
                        description: L("reminders_no_dog_description"),
                        systemImage: "pawprint"
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle(L("reminders_title"))
            .toolbar {
                if hasDog {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text(L("reminders_add")))
                    }
                }
            }
            .navigationDestination(isPresented: $showAddForm) {
                AddReminderView()
                    .toolbar(.hidden, for: .tabBar)
            }
            .confirmDialog(
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                title: L("reminder_delete_title"),
                message: L("reminder_delete_message"),
                confirmText: L("action_delete"),
                onConfirm: {
                    if let id = pendingDeleteId { store.deleteReminder(id: id) }
                    pendingDeleteId = nil
                }
            )
        }
    }

    @ViewBuilder
    private var listContent: some View {
        let reminders = store.reminders(forDog: store.activeDog?.id ?? "")
        if reminders.isEmpty {
            EmptyStateView(
                title: L("reminders_empty_title"),
                description: L("reminders_empty_description"),
                systemImage: "pills",
                action: {
                    AnyView(
                        Button(L("reminders_add")) { showAddForm = true }
                            .buttonStyle(.borderedProminent)
                    )
                }
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(reminders) { reminder in
                        ReminderItemView(
                            reminder: reminder,
                            onToggle: { enabled in
                                store.setReminderEnabled(id: reminder.id, isEnabled: enabled)
                            },
                            onDelete: { pendingDeleteId = reminder.id }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Элемент списка напоминаний

private struct ReminderItemView: View {
    @Environment(\.appColors) private var colors
    let reminder: Reminder
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(
                systemName: reminder.type == .medication ? "pills" : "fork.knife"
            )
            .foregroundStyle(colors.onSurfaceVariant)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.dcTitleMedium)
                    .foregroundStyle(reminder.isEnabled ? colors.onSurface : colors.onSurfaceVariant)
                Text(
                    L(reminder.type == .medication ? "reminder_type_medication" : "reminder_type_feeding")
                        + " • " + reminder.timeText
                )
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
                Text(daysText)
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(colors.onSurfaceVariant)
            }
        }
        .padding(16)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var daysText: String {
        // Все семь дней — «Каждый день»; иначе короткие имена через запятую
        if reminder.daysOfWeek.count == 7 {
            return L("reminder_every_day")
        }
        return reminder.daysOfWeek.sorted()
            .map { Formatters.weekdayShort(isoWeekday: $0) }
            .joined(separator: ", ")
    }
}

// MARK: - Форма нового напоминания; порт AddReminderScreen.kt

struct AddReminderView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var type: ReminderType = .medication
    @State private var title = ""
    @State private var time: Date?
    @State private var daysOfWeek: Set<Int> = []
    @State private var validationError: ValidationError?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $type) {
                    Text(L("reminder_type_medication")).tag(ReminderType.medication)
                    Text(L("reminder_type_feeding")).tag(ReminderType.feeding)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("reminder_title_label"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                    TextField("", text: $title)
                        .padding(12)
                        .background(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    validationError == .emptyReminderTitle ? colors.error : colors.outline.opacity(0.6),
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if validationError == .emptyReminderTitle {
                    errorText(L("error_reminder_title"))
                }

                TimeFieldRow(
                    label: L("reminder_time_label"),
                    value: time,
                    onValueChange: { date in
                        time = date
                    }
                )

                Text(L("reminder_days_label"))
                    .font(.dcTitleMedium)
                WeekdaySelector(
                    selectedDays: daysOfWeek,
                    onSelectionChange: { days in
                        daysOfWeek = days
                        validationError = nil
                    }
                )
                if validationError == .emptyReminderDays {
                    errorText(L("error_reminder_days"))
                }

                Text(L("reminder_hint"))
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)

                // Без времени сохранять нечего — кнопка неактивна
                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(colors.onPrimary)
                        } else {
                            Text(L("action_save"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || time == nil)
            }
            .padding(16)
        }
        .navigationTitle(L("reminder_add_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.dcBodyMedium)
            .foregroundStyle(colors.error)
    }

    private func save() {
        guard !isSaving, let time else { return }
        isSaving = true
        Task {
            // Разрешение запрашиваем в момент, когда пользователь реально сохраняет напоминание
            await NotificationScheduler.requestAuthorization()
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            let reminder = Reminder(
                id: "",
                dogId: store.activeDog?.id ?? "",
                type: type,
                title: title,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                daysOfWeek: daysOfWeek,
                isEnabled: true
            )
            let error = store.addReminder(reminder)
            isSaving = false
            if let error {
                validationError = error
            } else {
                dismiss()
            }
        }
    }
}
