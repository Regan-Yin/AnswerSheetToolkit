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

    var computedRows: Int { draft.computedRows }

    // MARK: - Layout (interrelated total / per-row / rows)

    /// Sets the total question count (open edit — may be indivisible) and
    /// re-suggests a near-square columns-per-row to fit it.
    func setTotalQuestions(_ total: Int) {
        let clamped = Self.clamp(total, to: AppSettings.totalQuestionsRange)
        draft.defaultTotalQuestions = clamped
        draft.defaultQuestionsPerRow = AppSettings.suggestedColumns(forTotal: clamped)
        commit()
    }

    /// Sets questions per row, keeping the current row count and recomputing the
    /// total (rows × per-row).
    func setQuestionsPerRow(_ perRow: Int) {
        let clamped = Self.clamp(perRow, to: AppSettings.questionsPerRowRange)
        let rows = draft.computedRows
        draft.defaultQuestionsPerRow = clamped
        draft.defaultTotalQuestions = Self.clamp(rows * clamped, to: AppSettings.totalQuestionsRange)
        commit()
    }

    /// Sets the row count, keeping per-row constant and recomputing the total
    /// (rows × per-row).
    func setRows(_ rows: Int) {
        let clampedRows = Self.clamp(rows, to: AppSettings.rowsRange)
        let perRow = draft.defaultQuestionsPerRow
        draft.defaultTotalQuestions = Self.clamp(clampedRows * perRow, to: AppSettings.totalQuestionsRange)
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
