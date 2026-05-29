import SwiftUI

/// Top toolbar: sidebar toggle, new sheet, mock-exam switch + timer, export, settings.
struct TopToolbarView: ToolbarContent {
    @EnvironmentObject private var store: AppStore

    var body: some ToolbarContent {
        ToolbarItem {
            Button {
                store.createSheet()
            } label: {
                Image(systemName: "plus")
            }
            .help(store.t("toolbar.newSheet"))
            .accessibilityLabel(store.t("toolbar.newSheet"))
            .accessibilityIdentifier("newSheetButton")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            mockExamControls
            exportMenu
            Button {
                store.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help(store.t("toolbar.settings"))
            .accessibilityLabel(store.t("toolbar.settings"))
        }
    }

    // MARK: - Mock exam controls

    @ViewBuilder
    private var mockExamControls: some View {
        if store.mockExamModeEnabled {
            if store.timer.isCountingDown {
                Text(store.t("mock.startingInShort", store.timer.countdownRemaining))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text(store.timer.formattedDisplay)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(store.timer.isRunning ? Color.accentColor : .secondary)
                    .help(store.t("mock.timer"))
            }
            if store.timer.phase == .ready {
                Button(store.t("mock.start")) { store.startTimerExplicitly() }
            } else if store.timer.phase == .idle, store.activeSheet != nil {
                Button(store.t("mock.start")) { store.beginMockAttempt() }
            }
        }

        Toggle(isOn: Binding(
            get: { store.mockExamModeEnabled },
            set: { store.setMockExamMode($0) }
        )) {
            Text(store.t("mock.mode"))
        }
        .toggleStyle(.switch)
        .help(store.t("mock.mode"))
        .accessibilityIdentifier("mockExamToggle")
    }

    // MARK: - Export menu

    private var exportMenu: some View {
        Menu {
            Button(store.t("export.toExcel")) { exportExcel() }
            Button(store.t("export.copyClipboard")) { copyClipboard() }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help(store.t("toolbar.export"))
        .disabled(exportTargets.isEmpty)
    }

    private var exportTargetIDs: Set<UUID> {
        if !store.selection.isEmpty { return store.selection }
        if let active = store.activeSheetID { return [active] }
        return []
    }

    private var exportTargets: [AnswerSheet] {
        store.sheets(for: exportTargetIDs)
    }

    private func exportExcel() {
        store.exportSheetsToExcel(exportTargetIDs)
    }

    private func copyClipboard() {
        store.copySheetsToClipboard(exportTargetIDs)
    }
}
