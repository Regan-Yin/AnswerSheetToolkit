import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Holds an editable draft of ``AppSettings`` and commits changes to the store.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var draft: AppSettings

    private unowned let store: AppStore

    init(store: AppStore) {
        self.store = store
        self.draft = store.settings
    }

    /// Reloads the draft from the store (e.g. when the settings sheet appears).
    func reload() {
        draft = store.settings
    }

    /// Commits the current draft. Layout changes apply only to new sheets.
    func commit() {
        store.updateSettings(draft)
        draft = store.settings
    }

    // MARK: - Layout (total = rows × per-row)

    /// Sets the total question count directly. Open edit — leaves rows and
    /// questions-per-row untouched.
    func setTotalQuestions(_ total: Int) {
        draft.defaultTotalQuestions = Self.clamp(total, to: AppSettings.totalQuestionsRange)
        commit()
    }

    /// Sets questions per row and recomputes the total (rows × per-row).
    func setQuestionsPerRow(_ perRow: Int) {
        let clamped = Self.clamp(perRow, to: AppSettings.questionsPerRowRange)
        draft.defaultQuestionsPerRow = clamped
        draft.defaultTotalQuestions = Self.clamp(draft.defaultRows * clamped, to: AppSettings.totalQuestionsRange)
        commit()
    }

    /// Sets the row count and recomputes the total (rows × per-row).
    func setRows(_ rows: Int) {
        let clamped = Self.clamp(rows, to: AppSettings.rowsRange)
        draft.defaultRows = clamped
        draft.defaultTotalQuestions = Self.clamp(clamped * draft.defaultQuestionsPerRow, to: AppSettings.totalQuestionsRange)
        commit()
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Sets the count-down duration hours, preserving the current minutes.
    func setDurationHours(_ hours: Int) {
        draft.mockExamDurationSeconds = hours * 3600 + draft.durationMinutes * 60
        commit()
    }

    /// Sets the count-down duration minutes, preserving the current hours.
    func setDurationMinutes(_ minutes: Int) {
        draft.mockExamDurationSeconds = draft.durationHours * 3600 + minutes * 60
        commit()
    }

    /// Presents a folder picker to choose the export destination.
    func chooseExportFolder() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK {
            draft.exportFolderURL = panel.url
            commit()
        }
        #endif
    }

    func clearExportFolder() {
        draft.exportFolderURL = nil
        commit()
    }
}
