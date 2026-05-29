import Foundation
import Combine

/// The central coordinator and source of truth.
///
/// Owns the answer sheets, settings, selection, and the child view models (editor,
/// timer). Coordinates persistence (autosave) and the mock-exam timing rules. Views
/// call intent methods here; they contain no business logic themselves.
@MainActor
final class AppStore: ObservableObject {
    @Published var sheets: [AnswerSheet]
    @Published var settings: AppSettings
    /// Sidebar multi-selection (used for batch export/copy/delete).
    @Published var selection: Set<UUID>
    /// The sheet currently shown in the grid.
    @Published var activeSheetID: UUID?
    @Published var showingSettings: Bool = false
    /// Mock Exam Mode toggle (session state, not persisted).
    @Published var mockExamModeEnabled: Bool = false

    let editor: AnswerSheetEditorViewModel
    let timer: MockExamTimerViewModel

    /// Transient in-app notification (toast) shown after exports.
    @Published var toast: ToastMessage?

    private let persistence: PersistenceService
    private let localization: LocalizationService
    private let exporter = ExportViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var toastTask: Task<Void, Never>?

    init(
        persistence: PersistenceService = PersistenceService(),
        localization: LocalizationService = .shared
    ) {
        self.persistence = persistence
        self.localization = localization
        let loadedSettings = persistence.loadSettings()
        self.settings = loadedSettings
        let loadedSheets = persistence.loadSheets()
        self.sheets = loadedSheets
        self.selection = []
        self.editor = AnswerSheetEditorViewModel()
        self.timer = MockExamTimerViewModel()

        if let first = loadedSheets.first {
            self.activeSheetID = first.id
            self.selection = [first.id]
        }

        wireEditor()
        bridgeChildUpdates()
        configureEditorForActiveSheet(resetFocus: true)
    }

    /// Forwards updates from the nested view models (editor focus, timer ticks) so
    /// that views observing the store re-render live, e.g. the per-second timer and
    /// the focus highlight while navigating with Tab / Shift+Tab.
    private func bridgeChildUpdates() {
        editor.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        timer.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // Count-down reaching zero: persist the result and end answering.
        timer.onAutoComplete = { [weak self] elapsed in
            guard let self, let idx = self.activeIndex else { return }
            self.sheets[idx].mockExamElapsedSeconds = elapsed
            self.sheets[idx].mockExamCompletedAt = Date()
            self.sheets[idx].updatedAt = Date()
            self.autosaveSheets()
            self.editor.exitAnsweringMode(reason: .manual)
        }
    }

    // MARK: - Localization

    /// Localized string for the current language.
    func t(_ key: String) -> String {
        localization.string(key, language: settings.language)
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: localization.string(key, language: settings.language), arguments: args)
    }

    // MARK: - Active sheet access

    var activeSheet: AnswerSheet? {
        guard let id = activeSheetID else { return nil }
        return sheets.first { $0.id == id }
    }

    private var activeIndex: Int? {
        guard let id = activeSheetID else { return nil }
        return sheets.firstIndex { $0.id == id }
    }

    // MARK: - Editor wiring

    private func wireEditor() {
        editor.onApplyAnswer = { [weak self] index, answer in
            self?.applyAnswer(answer, at: index)
        }
        editor.onAnswerCommitted = { [weak self] _, isFinal in
            self?.handleAnswerCommitted(isFinal: isFinal)
        }
        editor.onEnterAnswering = { [weak self] in
            self?.handleEnterAnswering()
        }
        editor.onExit = { [weak self] reason in
            self?.handleEditorExit(reason: reason)
        }
    }

    private func configureEditorForActiveSheet(resetFocus: Bool) {
        editor.configure(
            questionCount: activeSheet?.totalQuestions ?? 0,
            answerOptionCount: activeSheet?.allowedAnswerCount ?? 26,
            resetFocus: resetFocus
        )
    }

    // MARK: - Answer mutations

    private func applyAnswer(_ answer: String?, at index: Int) {
        guard let idx = activeIndex else { return }
        guard sheets[idx].answers.indices.contains(index) else { return }
        sheets[idx].answers[index].answer = answer
        sheets[idx].updatedAt = Date()
        autosaveSheets()
    }

    private func handleAnswerCommitted(isFinal: Bool) {
        guard mockExamModeEnabled else { return }
        // Safety net: if timing hasn't begun yet (e.g. lead-in finished and the user
        // started typing), begin on the first answer.
        if timer.phase == .ready {
            timer.beginTiming()
        }
        if isFinal {
            stopTimerAndSave(markCompleted: true)
        }
    }

    private func handleEnterAnswering() {
        // Re-entering the grid does not auto-restart a finished timer.
    }

    private func handleEditorExit(reason: AnsweringExitReason) {
        // Exiting answering mode (escape/sidebar) stops the timer and saves the result.
        stopTimerAndSave(markCompleted: false)
    }

    // MARK: - Sheet operations

    /// Creates a new sheet from the current settings snapshot, selects + focuses it,
    /// and enters answering mode (starting the mock flow if enabled).
    @discardableResult
    func createSheet() -> AnswerSheet {
        let snapshot = settings.validated()
        let title = t("sheet.untitled", sheets.count + 1)
        let sheet = AnswerSheet(
            title: title,
            totalQuestions: snapshot.defaultTotalQuestions,
            questionsPerRow: snapshot.defaultQuestionsPerRow,
            answerOptionCount: snapshot.defaultAnswerOptionCount,
            mockExamEnabledAtCreation: mockExamModeEnabled,
            mockExamTimerMode: snapshot.mockExamTimerMode,
            mockExamDurationSeconds: snapshot.mockExamDurationSeconds,
            languageSnapshot: snapshot.language,
            themeSnapshot: snapshot.theme
        )
        sheets.append(sheet)
        activeSheetID = sheet.id
        selection = [sheet.id]
        autosaveSheets()
        configureEditorForActiveSheet(resetFocus: true)
        editor.enterAnsweringMode(focus: 0)
        if mockExamModeEnabled {
            startMockFlow()
        }
        return sheet
    }

    /// Programmatically selects a single sheet for display.
    func selectSheet(_ id: UUID) {
        handleSidebarSelectionChange([id])
    }

    /// Handles a new sidebar selection set (from the list's multi-selection binding).
    /// Every selection change is a sidebar interaction: timing stops and answering
    /// mode exits (per the critical focus rule). Saved answers are preserved.
    func handleSidebarSelectionChange(_ newSelection: Set<UUID>) {
        sidebarInteraction()
        selection = newSelection
        if newSelection.count == 1, let only = newSelection.first {
            setActive(only)
        } else if let active = activeSheetID, newSelection.contains(active) {
            // Keep the current grid sheet when it remains part of a multi-selection.
        } else if let first = orderedFirst(of: newSelection) {
            setActive(first)
        }
    }

    private func orderedFirst(of ids: Set<UUID>) -> UUID? {
        sheets.first { ids.contains($0.id) }?.id
    }

    private func setActive(_ id: UUID) {
        guard activeSheetID != id else { return }
        activeSheetID = id
        timer.reset()
        configureEditorForActiveSheet(resetFocus: true)
    }

    func renameSheet(_ id: UUID, to newTitle: String) {
        guard let idx = sheets.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        sheets[idx].title = trimmed.isEmpty ? sheets[idx].title : trimmed
        sheets[idx].updatedAt = Date()
        autosaveSheets()
    }

    func deleteSheets(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        sidebarInteraction()
        let deletingActive = activeSheetID.map { ids.contains($0) } ?? false
        sheets.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        if deletingActive {
            activeSheetID = sheets.first?.id
            selection = activeSheetID.map { [$0] } ?? []
            timer.reset()
            configureEditorForActiveSheet(resetFocus: true)
        }
        autosaveSheets()
    }

    // MARK: - Sidebar focus rule

    /// Called for ANY sidebar interaction: stops countdown + timer, exits answering
    /// mode, and disables keyboard entry until the grid is focused again. Saved
    /// answers are never lost.
    func sidebarInteraction() {
        stopTimerAndSave(markCompleted: false)
        editor.exitAnsweringMode(reason: .sidebar)
    }

    // MARK: - Mock exam

    func setMockExamMode(_ enabled: Bool) {
        mockExamModeEnabled = enabled
        if !enabled {
            stopTimerAndSave(markCompleted: false)
            timer.reset()
        }
    }

    /// Starts the lead-in countdown (if configured); the timer begins automatically
    /// when the lead-in finishes (or immediately when there is no lead-in).
    private func startMockFlow() {
        guard mockExamModeEnabled else { return }
        let snapshot = settings.validated()
        timer.engage(
            mode: snapshot.mockExamTimerMode,
            durationSeconds: snapshot.mockExamDurationSeconds,
            countdownSeconds: snapshot.mockExamCountdownSeconds,
            onCountdownComplete: { [weak self] in
                self?.timer.beginTiming()
            }
        )
        // Capture the mode/duration used onto the active sheet for the record.
        if let idx = activeIndex {
            sheets[idx].mockExamTimerMode = snapshot.mockExamTimerMode
            sheets[idx].mockExamDurationSeconds = snapshot.mockExamDurationSeconds
            sheets[idx].mockExamStartedAt = Date()
        }
    }

    /// Explicit Start/Resume from the toolbar (only valid while `.ready`).
    func startTimerExplicitly() {
        guard mockExamModeEnabled else { return }
        if timer.phase == .ready {
            timer.beginTiming()
        }
    }

    /// Begin a fresh mock attempt for the active sheet (used when toggling on after a
    /// sheet already exists, or pressing Start before answering).
    func beginMockAttempt() {
        guard mockExamModeEnabled, activeSheet != nil else { return }
        editor.enterAnsweringMode(focus: editor.focusedIndex)
        startMockFlow()
    }

    private func stopTimerAndSave(markCompleted: Bool) {
        let result = timer.stop()
        guard let idx = activeIndex else { return }
        if let result {
            sheets[idx].mockExamElapsedSeconds = result
            sheets[idx].mockExamCompletedAt = markCompleted ? Date() : sheets[idx].mockExamCompletedAt
            sheets[idx].updatedAt = Date()
            autosaveSheets()
        }
    }

    // MARK: - Settings

    /// Updates settings. Layout fields only affect newly created sheets; existing
    /// sheets are never reshaped.
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings.validated()
        persistence.saveSettings(settings)
    }

    // MARK: - Export helpers

    /// Sheets corresponding to a set of ids, in display order.
    func sheets(for ids: Set<UUID>) -> [AnswerSheet] {
        sheets.filter { ids.contains($0.id) }
    }

    /// Exports the given sheets to Excel and shows a success/failure toast.
    func exportSheetsToExcel(_ ids: Set<UUID>) {
        let targets = sheets(for: ids)
        guard !targets.isEmpty else { return }
        switch exporter.exportToExcel(targets, settings: settings) {
        case .success(let url):
            showToast(t("export.successExcel", url.lastPathComponent), success: true)
        case .failure(let message):
            showToast(t("export.failed", message), success: false)
        case .cancelled:
            break
        }
    }

    /// Copies the given sheets to the clipboard as TSV and shows a toast.
    func copySheetsToClipboard(_ ids: Set<UUID>) {
        let targets = sheets(for: ids)
        guard !targets.isEmpty else { return }
        exporter.copyToClipboard(targets)
        showToast(t("export.successClipboard"), success: true)
    }

    /// Shows a transient toast that auto-dismisses.
    func showToast(_ message: String, success: Bool) {
        toast = ToastMessage(message: message, isSuccess: success)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - Persistence

    private func autosaveSheets() {
        persistence.saveSheets(sheets)
    }
}

/// A transient in-app notification.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var isSuccess: Bool
}
