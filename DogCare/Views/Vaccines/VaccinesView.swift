import SwiftUI

// Экран прививок; порт VaccineListScreen.kt + VaccineListViewModel.kt
struct VaccinesTab: View {
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
                        title: L("vaccines_no_dog_title"),
                        description: L("vaccines_no_dog_description"),
                        systemImage: "pawprint"
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle(L("vaccines_title"))
            .toolbar {
                if hasDog {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text(L("vaccines_add")))
                    }
                }
            }
            .navigationDestination(isPresented: $showAddForm) {
                AddVaccineView()
                    .toolbar(.hidden, for: .tabBar)
            }
            .confirmDialog(
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                title: L("vaccine_delete_title"),
                message: L("vaccine_delete_message"),
                confirmText: L("action_delete"),
                onConfirm: {
                    if let id = pendingDeleteId { store.deleteVaccine(id: id) }
                    pendingDeleteId = nil
                }
            )
        }
    }

    @ViewBuilder
    private var listContent: some View {
        let vaccines = store.vaccines(forDog: store.activeDog?.id ?? "")
        if vaccines.isEmpty {
            EmptyStateView(
                title: L("vaccines_empty_title"),
                description: L("vaccines_empty_description"),
                systemImage: "cross.case",
                action: {
                    AnyView(
                        Button(L("vaccines_add")) { showAddForm = true }
                            .buttonStyle(.borderedProminent)
                    )
                }
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vaccines) { vaccine in
                        VaccineItemView(
                            vaccine: vaccine,
                            onDelete: { pendingDeleteId = vaccine.id }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Элемент списка прививок
// Состояние срока: просрочена — красным, скоро (7 дней) — акцентом

private struct VaccineItemView: View {
    @Environment(\.appColors) private var colors
    let vaccine: Vaccine
    let onDelete: () -> Void

    private enum DueState { case overdue, soon, normal }

    private var dueState: DueState {
        guard let due = vaccine.nextDueDate else { return .normal }
        let today = Date().startOfDay
        if due.startOfDay < today { return .overdue }
        if let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: today),
           due.startOfDay <= weekLater {
            return .soon
        }
        return .normal
    }

    private var dueColor: Color {
        switch dueState {
        case .overdue: return colors.error
        case .soon: return colors.primary
        case .normal: return colors.onSurfaceVariant
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vaccine.name)
                    .font(.dcTitleMedium)
                    .foregroundStyle(colors.onSurface)
                Text(L("vaccine_given_on", Formatters.formatDate(vaccine.dateGiven)))
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)
                if let due = vaccine.nextDueDate {
                    Text(L("vaccine_next_on", Formatters.formatDate(due)))
                        .font(.dcBodyMedium)
                        .foregroundStyle(dueColor)
                }
            }
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
}

// MARK: - Форма новой прививки; порт AddVaccineScreen.kt + AddVaccineViewModel.kt

struct AddVaccineView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    // Дата прививки предзаполняется сегодняшней — типичный сценарий
    @State private var dateGiven = Date()
    @State private var nextDueDate: Date?
    @State private var validationError: ValidationError?
    @State private var isSaving = false
    @State private var notificationsDenied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("vaccine_name_label"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                    TextField("", text: $name)
                        .padding(12)
                        .background(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    validationError == .emptyVaccineName ? colors.error : colors.outline.opacity(0.6),
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if validationError == .emptyVaccineName {
                    errorText(L("error_vaccine_name"))
                }

                DateFieldRow(
                    label: L("vaccine_date_given_label"),
                    value: dateGiven,
                    onValueChange: { date in
                        dateGiven = date
                        validationError = nil
                    },
                    maximumDate: Date()
                )

                DateFieldRow(
                    label: L("vaccine_next_due_label"),
                    value: nextDueDate,
                    onValueChange: { date in
                        nextDueDate = date
                        validationError = nil
                    },
                    minimumDate: dateGiven
                )
                if validationError == .invalidVaccineDate {
                    errorText(L("error_vaccine_date"))
                }

                Text(L("vaccine_reminder_hint"))
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)

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
                .disabled(isSaving)
            }
            .padding(16)
        }
        .navigationTitle(L("vaccine_add_title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            L("error_generic"),
            isPresented: $notificationsDenied
        ) {
            Button(L("action_ok"), role: .cancel) {}
        } message: {
            Text(L("notifications_permission_hint"))
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.dcBodyMedium)
            .foregroundStyle(colors.error)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            // Разрешение запрашиваем в момент, когда пользователь реально сохраняет запись
            await NotificationScheduler.requestAuthorization()
            let error = store.addVaccine(
                dogId: store.activeDog?.id ?? "",
                name: name,
                dateGiven: dateGiven.startOfDay,
                nextDueDate: nextDueDate
            )
            isSaving = false
            if let error {
                validationError = error
            } else {
                dismiss()
            }
        }
    }
}
