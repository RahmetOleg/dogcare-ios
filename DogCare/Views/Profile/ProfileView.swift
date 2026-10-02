import SwiftUI
import PhotosUI

// Экран профиля активной собаки; порт ProfileScreen.kt + ProfileViewModel.kt
struct ProfileTab: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors

    @State private var isLoading = true
    @State private var showDeleteDialog = false
    @State private var showForm = false
    @State private var isEditMode = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let dog = store.activeDog {
                    profileContent(dog)
                } else {
                    EmptyStateView(
                        title: L("profile_empty_title"),
                        description: L("profile_empty_description"),
                        systemImage: "pawprint",
                        action: {
                            AnyView(
                                Button(L("profile_add_dog")) {
                                    isEditMode = false
                                    showForm = true
                                }
                                .buttonStyle(.borderedProminent)
                            )
                        }
                    )
                }
            }
            .navigationTitle(L("profile_title"))
            .toolbar {
                if store.activeDog != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isEditMode = true
                            showForm = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteDialog = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showForm) {
                DogFormView(isEditMode: isEditMode)
                    .toolbar(.hidden, for: .tabBar)
            }
            .confirmDialog(
                isPresented: $showDeleteDialog,
                title: L("profile_delete_title"),
                message: L("profile_delete_message"),
                confirmText: L("action_delete"),
                onConfirm: {
                    if let dog = store.activeDog {
                        store.deleteDog(id: dog.id)
                    }
                }
            )
            .alert(
                L("error_generic"),
                isPresented: Binding(
                    get: { photoErrorMessage != nil },
                    set: { if !$0 { photoErrorMessage = nil } }
                )
            ) {
                Button(L("action_ok"), role: .cancel) {}
            } message: {
                Text(photoErrorMessage ?? "")
            }
            .task {
                // Данные загружаются из хранилища синхронно в init — снимаем спиннер
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ dog: Dog) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                photoPicker(dog)

                Text(dog.name)
                    .font(.dcHeadline)
                    .foregroundStyle(colors.onBackground)
                Text(dog.breed)
                    .font(.dcBodyLarge)
                    .foregroundStyle(colors.onSurfaceVariant)

                detailsCard(dog)
                    .padding(.top, 4)
            }
            .padding(16)
        }
    }

    // Аватар кликабелен: тап по нему открывает галерею; выбранное фото
    // копируется во внутреннее хранилище и сразу подставляется в профиль
    private func photoPicker(_ dog: Dog) -> some View {
        ZStack(alignment: .bottomTrailing) {
            DogAvatar(photoPath: dog.photoPath, contentDescription: dog.name, size: 120)
            Circle()
                .fill(colors.primary)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.onPrimary)
                )
        }
        .onTapGesture { showPhotoPicker = true }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { newItem in
            guard let newItem else { return }
            Task {
                defer { selectedPhoto = nil }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let path = DogPhotoStorage.save(data) else {
                    photoErrorMessage = L("error_photo")
                    return
                }
                store.updateDogPhoto(id: dog.id, photoPath: path)
            }
        }
    }

    @ViewBuilder
    private func detailsCard(_ dog: Dog) -> some View {
        SectionCard(title: L("profile_info")) {
            VStack(spacing: 12) {
                infoRow(
                    systemImage: "birthday.cake",
                    label: L("profile_birth_date"),
                    value: Formatters.formatDate(dog.birthDate)
                )
                infoRow(
                    systemImage: "calendar",
                    label: L("profile_age"),
                    value: {
                        let age = DogAgeCalculator.age(birthDate: dog.birthDate)
                        return ageText(years: age.years, months: age.months)
                    }()
                )
                infoRow(
                    systemImage: "scalemass",
                    label: L("profile_weight"),
                    value: L("weight_format", Formatters.formatWeight(dog.weightKg))
                )
                infoRow(
                    systemImage: dog.gender == .male ? "figure.stand" : "figure.dress.line.vertical.figure",
                    label: L("profile_gender"),
                    value: L(dog.gender == .male ? "gender_male" : "gender_female")
                )
            }
        }
    }

    private func infoRow(systemImage: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(colors.onSurfaceVariant)
            Text(label)
                .font(.dcBodyMedium)
                .foregroundStyle(colors.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.dcBodyLarge)
                .foregroundStyle(colors.onSurface)
        }
    }
}
