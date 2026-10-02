import SwiftUI
import PhotosUI

// Форма добавления/редактирования собаки; порт DogFormScreen.kt + DogFormViewModel.kt
struct DogFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    let isEditMode: Bool

    @State private var name = ""
    @State private var breed = ""
    @State private var birthDate: Date?
    @State private var weightText = ""
    @State private var gender: Gender?
    @State private var photoPath: String?
    @State private var allergies = ""
    @State private var chronicConditions = ""
    @State private var validationError: ValidationError?
    @State private var isSaving = false

    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showGenericError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoField

                labeledField(label: L("profile_name_label"), text: $name, isError: validationError == .emptyName)
                if validationError == .emptyName {
                    errorText(L("error_name"))
                }

                labeledField(label: L("profile_breed_label"), text: $breed, isError: validationError == .emptyBreed)
                if validationError == .emptyBreed {
                    errorText(L("error_breed"))
                }

                DateFieldRow(
                    label: L("profile_birth_label"),
                    value: birthDate,
                    onValueChange: { date in
                        birthDate = date
                        validationError = nil
                    },
                    maximumDate: Date()
                )
                if validationError == .invalidBirthDate {
                    errorText(L("error_date"))
                }

                DecimalField(
                    title: L("profile_weight_label"),
                    text: $weightText,
                    isError: validationError == .invalidWeight
                )
                .onChange(of: weightText) { newValue in
                    // Только цифры и разделители, как в Android-версии
                    weightText = newValue.filter { $0.isNumber || $0 == "," || $0 == "." }
                    validationError = nil
                }
                if validationError == .invalidWeight {
                    errorText(L("error_weight"))
                }

                genderSelector
                if validationError == .genderNotSelected {
                    errorText(L("error_gender"))
                }

                // Персонализация справочника опасностей
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("profile_allergies_label"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                    TextField(L("profile_allergies_hint"), text: $allergies)
                        .padding(12)
                        .background(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("profile_chronic_label"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                    TextField(L("profile_chronic_hint"), text: $chronicConditions)
                        .padding(12)
                        .background(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                saveButton
            }
            .padding(16)
        }
        .navigationTitle(L(isEditMode ? "profile_edit_title" : "profile_add_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { loadEditingDog() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { newItem in
            guard let newItem else { return }
            Task {
                defer { selectedPhoto = nil }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let path = DogPhotoStorage.save(data) else {
                    showGenericError = true
                    return
                }
                photoPath = path
            }
        }
        .alert(
            L("error_photo"),
            isPresented: $showGenericError
        ) {
            Button(L("action_ok"), role: .cancel) {}
        }
    }

    private var photoField: some View {
        HStack(spacing: 16) {
            DogAvatar(photoPath: photoPath, contentDescription: nil, size: 72)
            Button(L("profile_photo_action")) { showPhotoPicker = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private var genderSelector: some View {
        Picker(L("profile_gender"), selection: $gender) {
            Text(L("gender_male")).tag(Gender?.some(.male))
            Text(L("gender_female")).tag(Gender?.some(.female))
        }
        .pickerStyle(.segmented)
        .onChange(of: gender) { _ in validationError = nil }
    }

    private var saveButton: some View {
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

    private func labeledField(label: String, text: Binding<String>, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
            TextField("", text: text)
                .padding(12)
                .background(colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isError ? colors.error : colors.outline.opacity(0.6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.dcBodyMedium)
            .foregroundStyle(colors.error)
    }

    private func loadEditingDog() {
        guard isEditMode, let dog = store.activeDog else { return }
        name = dog.name
        breed = dog.breed
        birthDate = dog.birthDate
        weightText = Formatters.formatWeight(dog.weightKg).replacingOccurrences(of: ",", with: ".")
        gender = dog.gender
        photoPath = dog.photoPath
        allergies = dog.allergies ?? ""
        chronicConditions = dog.chronicConditions ?? ""
    }

    private func save() {
        isSaving = true
        // Разделитель дробной части приводим к точке: «32,5» и «32.5» равнозначны
        let normalizedWeight = weightText.replacingOccurrences(of: ",", with: ".")
        let draft = DogProfileValidator.Draft(
            name: name,
            breed: breed,
            birthDate: birthDate,
            weightKg: Double(normalizedWeight),
            gender: gender,
            photoPath: photoPath,
            allergies: allergies.isEmpty ? nil : allergies,
            chronicConditions: chronicConditions.isEmpty ? nil : chronicConditions
        )
        let error: ValidationError?
        if isEditMode, let dog = store.activeDog {
            error = store.updateDog(id: dog.id, draft)
        } else {
            error = store.addDog(draft)
        }
        isSaving = false
        if let error {
            // Ошибку валидации показываем инлайн у поля, без алерта
            validationError = error
        } else {
            dismiss()
        }
    }
}

// Числовое поле в стиле остальных полей формы
struct DecimalField: View {
    @Environment(\.appColors) private var colors
    let title: String
    @Binding var text: String
    var isError: Bool = false

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
                        .stroke(isError ? colors.error : colors.outline.opacity(0.6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
