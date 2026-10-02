import SwiftUI

// Экран прогулок с таймером; порт WalkScreen.kt + WalkViewModel.kt
struct WalksTab: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appColors) private var colors

    // Внутреннее состояние таймера
    @State private var timerStart: Date?
    @State private var elapsedSeconds: Int = 0
    @State private var note = ""
    @State private var isSaving = false
    @State private var pendingDeleteId: String?
    @State private var ticker: Timer?
    @State private var showTooShortError = false

    private var hasDog: Bool { store.activeDog != nil }
    private var isActive: Bool { timerStart != nil }

    var body: some View {
        NavigationStack {
            Group {
                if !hasDog {
                    EmptyStateView(
                        title: L("walk_no_dog_title"),
                        description: L("walk_no_dog_description"),
                        systemImage: "pawprint"
                    )
                } else {
                    walkContent
                }
            }
            .navigationTitle(L("walks_title"))
            .confirmDialog(
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                title: L("walk_delete_title"),
                message: L("walk_delete_message"),
                confirmText: L("action_delete"),
                onConfirm: {
                    if let id = pendingDeleteId { store.deleteWalk(id: id) }
                    pendingDeleteId = nil
                }
            )
            .alert(
                L("error_walk_too_short"),
                isPresented: $showTooShortError
            ) {
                Button(L("action_ok"), role: .cancel) {}
            }
            .onDisappear { ticker?.invalidate() }
        }
    }

    private var walkContent: some View {
        List {
            Section {
                TimerCard(
                    isActive: isActive,
                    elapsedSeconds: elapsedSeconds,
                    note: $note,
                    isSaving: isSaving,
                    onStart: startWalk,
                    onStop: stopWalk,
                    onDiscard: resetTimer
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } header: {
                Text(L("walk_history"))
                    .font(.dcTitleMedium)
                    .foregroundStyle(colors.onSurface)
                    .textCase(nil)
            }

            let walks = store.walks(forDog: store.activeDog?.id ?? "")
            if walks.isEmpty && !isActive {
                Section {
                    EmptyStateView(
                        title: L("walk_empty_title"),
                        description: L("walk_empty_description")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(walks) { walk in
                        WalkItemView(
                            walk: walk,
                            onDelete: { pendingDeleteId = walk.id }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // Тик раз в секунду; elapsed каждый раз вычисляется заново — без накопления дрейфа
    private func startWalk() {
        guard timerStart == nil, store.activeDog != nil else { return }
        timerStart = Date()
        elapsedSeconds = 0
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let start = timerStart else { return }
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    private func stopWalk() {
        guard let start = timerStart else { return }
        isSaving = true
        let duration = Int(Date().timeIntervalSince(start))
        let result = store.saveWalk(
            dogId: store.activeDog?.id ?? "",
            startedAt: start,
            durationSeconds: duration,
            note: note
        )
        isSaving = false
        if result != nil {
            // Прогулка слишком короткая для сохранения
            showTooShortError = true
        } else {
            resetTimer()
        }
    }

    private func resetTimer() {
        ticker?.invalidate()
        ticker = nil
        timerStart = nil
        elapsedSeconds = 0
        note = ""
    }
}

// MARK: - Карточка таймера (порт TimerCard)

private struct TimerCard: View {
    @Environment(\.appColors) private var colors
    let isActive: Bool
    let elapsedSeconds: Int
    @Binding var note: String
    let isSaving: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        SectionCard(title: L("walk_timer_title")) {
            VStack(spacing: 8) {
                Text(Formatters.formatDuration(totalSeconds: elapsedSeconds))
                    .font(.dcHeadline)
                    .foregroundStyle(isActive ? colors.primary : colors.onSurface)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("walk_note_label"))
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                    TextField("", text: $note)
                        .padding(12)
                        .background(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.outline.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 4)

                HStack(spacing: 12) {
                    if !isActive {
                        Button(action: onStart) {
                            Text(L("walk_start"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: onStop) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text(L("walk_stop"))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)

                        Button(action: onDiscard) {
                            Text(L("walk_discard"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaving)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Элемент истории прогулок (порт WalkItem)

private struct WalkItemView: View {
    @Environment(\.appColors) private var colors
    let walk: Walk
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "walk_started_at",
                        Formatters.formatDate(walk.startedAt),
                        Formatters.formatTime(walk.startedAt)
                    )
                )
                .font(.dcTitleMedium)
                .foregroundStyle(colors.onSurface)
                Text(Formatters.formatDuration(totalSeconds: walk.durationSeconds))
                    .font(.dcBodyMedium)
                    .foregroundStyle(colors.onSurfaceVariant)
                if !walk.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(walk.note)
                        .font(.dcBodyMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
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
