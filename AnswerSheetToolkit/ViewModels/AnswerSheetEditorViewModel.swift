import Foundation
import Combine

/// Reason an answering session ended. Used to coordinate the timer.
enum AnsweringExitReason: Equatable {
    case escape
    case sidebar
    case manual
    case sheetChanged
}

/// Owns the answering-mode UI state (whether keyboard entry is active and which
/// question is focused) and translates keyboard intents into data mutations via
/// wiring callbacks. Contains no AppKit/data-store dependencies so it is unit
/// testable in isolation.
@MainActor
final class AnswerSheetEditorViewModel: ObservableObject {
    @Published private(set) var isAnswering: Bool = false
    @Published var focusedIndex: Int = 0
    private(set) var questionCount: Int = 0
    /// Allowed answer choices for the active sheet (counted from `A`).
    private(set) var answerOptionCount: Int = 26

    // MARK: Wiring (set by the coordinator)

    /// Persist an answer (`nil` clears) at a 0-based index.
    var onApplyAnswer: ((Int, String?) -> Void)?
    /// Fired after a *valid letter* is committed: (index, isFinalQuestion).
    var onAnswerCommitted: ((Int, Bool) -> Void)?
    /// Fired when answering mode is (re)entered.
    var onEnterAnswering: (() -> Void)?
    /// Fired when answering mode exits, with the reason.
    var onExit: ((AnsweringExitReason) -> Void)?

    // MARK: Configuration

    /// Configures the editor for a sheet with `questionCount` questions and the
    /// sheet's allowed answer-choice count.
    func configure(questionCount: Int, answerOptionCount: Int, resetFocus: Bool) {
        self.questionCount = max(0, questionCount)
        self.answerOptionCount = max(1, answerOptionCount)
        if resetFocus {
            focusedIndex = 0
        } else {
            focusedIndex = GridNavigator.clamp(focusedIndex, count: self.questionCount)
        }
    }

    // MARK: Mode

    func enterAnsweringMode(focus index: Int = 0) {
        guard questionCount > 0 else { return }
        focusedIndex = GridNavigator.clamp(index, count: questionCount)
        let wasAnswering = isAnswering
        isAnswering = true
        if !wasAnswering { onEnterAnswering?() }
    }

    func exitAnsweringMode(reason: AnsweringExitReason) {
        guard isAnswering else { return }
        isAnswering = false
        onExit?(reason)
    }

    // MARK: Keyboard intents

    /// Handles a typed character. Returns `true` if it was a valid letter that was
    /// applied (and focus advanced); `false` for ignored input.
    @discardableResult
    func handleCharacter(_ raw: String) -> Bool {
        guard isAnswering, questionCount > 0 else { return false }
        guard let normalized = AnswerValidator.normalize(raw, optionCount: answerOptionCount) else { return false }
        let target = focusedIndex
        onApplyAnswer?(target, normalized)
        let isFinal = GridNavigator.isLast(target, count: questionCount)
        onAnswerCommitted?(target, isFinal)
        focusedIndex = GridNavigator.next(from: target, count: questionCount)
        return true
    }

    /// Tab: move to next question, leaving the current one unchanged.
    func moveNext() {
        guard isAnswering, questionCount > 0 else { return }
        focusedIndex = GridNavigator.next(from: focusedIndex, count: questionCount)
    }

    /// Shift+Tab: move to previous question.
    func movePrevious() {
        guard isAnswering, questionCount > 0 else { return }
        focusedIndex = GridNavigator.previous(from: focusedIndex, count: questionCount)
    }

    /// Delete/Backspace: clear the current answer (no focus change).
    func clearCurrent() {
        guard isAnswering, questionCount > 0 else { return }
        onApplyAnswer?(focusedIndex, nil)
    }

    /// Mouse click on a cell: focus it and (re)enter answering mode.
    func focusCell(_ index: Int) {
        guard questionCount > 0 else { return }
        enterAnsweringMode(focus: index)
    }
}
