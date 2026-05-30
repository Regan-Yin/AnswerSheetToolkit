import SwiftUI

/// Settings page: question layout (new sheets only), export folder, language, theme,
/// and mock-exam countdown.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModelHost = SettingsViewModelHost()

    var body: some View {
        let vm = viewModel.resolve(store: store)
        Form {
            Section(store.t("settings.layout")) {
                NumericField(
                    title: store.t("settings.totalQuestions"),
                    value: vm.draft.defaultTotalQuestions,
                    range: AppSettings.totalQuestionsRange,
                    onChange: { vm.setTotalQuestions($0) }
                )
                NumericField(
                    title: store.t("settings.questionsPerRow"),
                    value: vm.draft.defaultQuestionsPerRow,
                    range: AppSettings.questionsPerRowRange,
                    onChange: { vm.setQuestionsPerRow($0) }
                )
                NumericField(
                    title: store.t("settings.rows"),
                    value: vm.draft.defaultRows,
                    range: AppSettings.rowsRange,
                    onChange: { vm.setRows($0) }
                )
                Stepper(value: Binding(
                    get: { vm.draft.defaultAnswerOptionCount },
                    set: { vm.draft.defaultAnswerOptionCount = $0; vm.commit() }
                ), in: AppSettings.answerOptionRange) {
                    LabeledContent(store.t("settings.answerChoices"),
                                   value: vm.draft.answerChoicesPreview)
                }
                Text(store.t("settings.layoutHelp"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(store.t("settings.export")) {
                LabeledContent(store.t("settings.exportFolder")) {
                    Text(vm.draft.exportFolderURL?.path ?? store.t("settings.exportFolderNone"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(store.t("settings.chooseFolder")) { vm.chooseExportFolder() }
                    if vm.draft.exportFolderURL != nil {
                        Button(store.t("settings.clearFolder")) { vm.clearExportFolder() }
                    }
                }
            }

            Section(store.t("settings.language")) {
                Picker(store.t("settings.language"), selection: Binding(
                    get: { vm.draft.language },
                    set: { vm.draft.language = $0; vm.commit() }
                )) {
                    ForEach(LanguageMode.allCases) { lang in
                        Text(store.t(lang.localizationKey)).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(store.t("settings.theme")) {
                Picker(store.t("settings.theme"), selection: Binding(
                    get: { vm.draft.theme },
                    set: { vm.draft.theme = $0; vm.commit() }
                )) {
                    ForEach(ThemeMode.allCases) { theme in
                        Text(store.t(theme.localizationKey)).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(store.t("settings.mockExam")) {
                Picker(store.t("settings.timingMode"), selection: Binding(
                    get: { vm.draft.mockExamTimerMode },
                    set: { vm.draft.mockExamTimerMode = $0; vm.commit() }
                )) {
                    ForEach(MockTimerMode.allCases) { mode in
                        Text(store.t(mode.localizationKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if vm.draft.mockExamTimerMode == .countDown {
                    NumericField(
                        title: store.t("settings.durationHours"),
                        value: vm.draft.durationHours,
                        range: AppSettings.durationHoursRange,
                        onChange: { vm.setDurationHours($0) }
                    )
                    NumericField(
                        title: store.t("settings.durationMinutes"),
                        value: vm.draft.durationMinutes,
                        range: AppSettings.durationMinutesRange,
                        onChange: { vm.setDurationMinutes($0) }
                    )
                    LabeledContent(store.t("settings.durationTotal"),
                                   value: MockExamTimerViewModel.format(vm.draft.mockExamDurationSeconds))
                }

                Picker(store.t("settings.countdown"), selection: Binding(
                    get: { vm.draft.mockExamCountdownSeconds },
                    set: { vm.draft.mockExamCountdownSeconds = $0; vm.commit() }
                )) {
                    ForEach(AppSettings.countdownOptions, id: \.self) { seconds in
                        Text(store.t("settings.countdownSeconds", seconds)).tag(seconds)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 540)
        .navigationTitle(store.t("toolbar.settings"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(store.t("common.done")) { dismiss() }
            }
        }
        .background(palette.windowBackground)
    }
}

/// A trailing-aligned text field that accepts digits only and clamps to a range.
private struct NumericField: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void
    @State private var text: String

    init(title: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) {
        self.title = title
        self.value = value
        self.range = range
        self.onChange = onChange
        _text = State(initialValue: String(value))
    }

    /// Max digits allowed, derived from the range's upper bound.
    private var maxDigits: Int { String(range.upperBound).count }

    var body: some View {
        LabeledContent(title) {
            TextField("", text: $text)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, newValue in
                    // Force digits only — letters/symbols are stripped.
                    let digits = String(newValue.filter(\.isNumber).prefix(maxDigits))
                    if digits != newValue {
                        text = digits
                        return
                    }
                    if let number = Int(digits) {
                        onChange(min(max(number, range.lowerBound), range.upperBound))
                    }
                }
                .onChange(of: value) { _, newValue in
                    if Int(text) != newValue { text = String(newValue) }
                }
                .onSubmit { normalize() }
        }
    }

    private func normalize() {
        let number = Int(text) ?? range.lowerBound
        let clamped = min(max(number, range.lowerBound), range.upperBound)
        text = String(clamped)
        onChange(clamped)
    }
}

/// Holds the `SettingsViewModel` so it survives view updates without requiring the
/// store at initialization time.
@MainActor
final class SettingsViewModelHost: ObservableObject {
    private var viewModel: SettingsViewModel?

    func resolve(store: AppStore) -> SettingsViewModel {
        if let viewModel { return viewModel }
        let vm = SettingsViewModel(store: store)
        viewModel = vm
        return vm
    }
}
