import SwiftUI

/// A single question cell: question number + one-letter answer box.
struct AnswerCellView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.palette) private var palette

    let entry: AnswerEntry
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("\(entry.questionNumber)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
                    .frame(minWidth: 26, alignment: .trailing)
                Text(entry.answer ?? "")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(palette.cellBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isFocused ? palette.focusRing : palette.cellBorder,
                                    lineWidth: isFocused ? 2.5 : 1)
                    )
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isFocused ? palette.focusRing.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isFocused ? [.isSelected] : [])
    }

    private var accessibilityLabel: String {
        if let answer = entry.answer {
            return store.t("a11y.questionAnswered", entry.questionNumber, answer)
        } else {
            return store.t("a11y.questionUnanswered", entry.questionNumber)
        }
    }
}
