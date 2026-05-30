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

    /// Approximate rendered width of a single cell (number + box + spacing), used
    /// to decide how many columns fit the current window width.
    private let approxCellWidth: CGFloat = 76
    private let gridPadding: CGFloat = 20

    /// Visual columns for the current width, never more than the configured
    /// questions-per-row. Exports always use the configured value, not this.
    private func visualColumns(width: CGFloat, perRow: Int) -> Int {
        let usable = max(0, width - gridPadding * 2)
        let fit = Int((usable / approxCellWidth).rounded(.down))
        return max(1, min(perRow, fit))
    }

    private func gridBody(sheet: AnswerSheet) -> some View {
        let perRow = max(1, sheet.questionsPerRow)

        return GeometryReader { geo in
            let columns = visualColumns(width: geo.size.width, perRow: perRow)
            let rows = stride(from: 0, to: sheet.answers.count, by: columns).map { start in
                Array(sheet.answers[start..<min(start + columns, sheet.answers.count)])
            }

            ScrollViewReader { proxy in
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
                    .padding(gridPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: store.editor.focusedIndex) { _, index in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
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
