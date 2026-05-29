import SwiftUI

/// The answer grid for the active sheet, with keyboard-first entry.
struct AnswerGridView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.palette) private var palette

    private var sheet: AnswerSheet? { store.activeSheet }

    private var inputLocked: Bool { store.timer.isCountingDown }

    var body: some View {
        Group {
            if let sheet {
                gridBody(sheet: sheet)
            }
        }
    }

    private func gridBody(sheet: AnswerSheet) -> some View {
        let perRow = max(1, sheet.questionsPerRow)
        let rows = stride(from: 0, to: sheet.answers.count, by: perRow).map { start in
            Array(sheet.answers[start..<min(start + perRow, sheet.answers.count)])
        }

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, rowEntries in
                        HStack(spacing: 8) {
                            ForEach(rowEntries) { entry in
                                AnswerCellView(
                                    entry: entry,
                                    isFocused: store.editor.isAnswering
                                        && (entry.questionNumber - 1) == store.editor.focusedIndex,
                                    onTap: { focusCell(entry.questionNumber - 1) }
                                )
                                .id(entry.questionNumber - 1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(20)
            }
            .onChange(of: store.editor.focusedIndex) { _, index in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
        .background(palette.windowBackground)
        .background(
            KeyCaptureView(
                isActive: store.editor.isAnswering,
                isLocked: inputLocked,
                onLetter: { store.editor.handleCharacter($0) },
                onTab: { store.editor.moveNext() },
                onShiftTab: { store.editor.movePrevious() },
                onEscape: { store.editor.exitAnsweringMode(reason: .escape) },
                onDelete: { store.editor.clearCurrent() }
            )
        )
        .overlay(alignment: .center) { countdownOverlay }
        .accessibilityLabel(store.t("a11y.answerGrid"))
        .accessibilityIdentifier("answerGrid")
        .accessibilityValue(store.editor.isAnswering ? "\(store.editor.focusedIndex + 1)" : "")
    }

    // MARK: - Countdown overlay

    @ViewBuilder
    private var countdownOverlay: some View {
        if store.timer.isCountingDown {
            VStack(spacing: 8) {
                Text(store.t("mock.startingIn"))
                    .font(.headline)
                    .foregroundStyle(palette.secondaryText)
                Text("\(store.timer.countdownRemaining)")
                    .font(.system(size: 64, weight: .bold).monospacedDigit())
                    .foregroundStyle(palette.accent)
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Mouse

    private func focusCell(_ index: Int) {
        store.editor.focusCell(index)
    }
}
