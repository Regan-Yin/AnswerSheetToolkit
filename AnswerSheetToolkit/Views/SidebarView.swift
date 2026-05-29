import SwiftUI

/// Left sidebar listing all answer sheets with create/select/rename/delete and
/// right-click export/copy. Any interaction here stops timing and exits answering.
struct SidebarView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.palette) private var palette

    @State private var renamingID: UUID?
    @State private var renameText: String = ""

    private var selectionBinding: Binding<Set<UUID>> {
        Binding(
            get: { store.selection },
            set: { store.handleSidebarSelectionChange($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                ForEach(store.sheets) { sheet in
                    SidebarRow(sheet: sheet)
                        .tag(sheet.id)
                        .accessibilityIdentifier("sheetRow")
                        .contextMenu { contextMenu(for: sheet) }
                }
            }
            .listStyle(.sidebar)
            // Clicks on empty list space still count as a sidebar interaction.
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { store.sidebarInteraction() }
            )
            sidebarFooter
        }
        .background(palette.surface)
        .alert(store.t("sidebar.rename"), isPresented: renameAlertPresented) {
            TextField(store.t("sidebar.renamePlaceholder"), text: $renameText)
            Button(store.t("common.cancel"), role: .cancel) { renamingID = nil }
            Button(store.t("common.save")) { commitRename() }
        }
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        HStack {
            Button {
                store.createSheet()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help(store.t("toolbar.newSheet"))
            .accessibilityLabel(store.t("toolbar.newSheet"))

            Button {
                store.deleteSheets(targetIDs(for: nil))
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(store.selection.isEmpty)
            .help(store.t("sidebar.delete"))
            .accessibilityLabel(store.t("sidebar.delete"))

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(palette.surface)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for sheet: AnswerSheet) -> some View {
        let ids = targetIDs(for: sheet.id)
        Button(store.t("export.toExcel")) { exportExcel(ids) }
        Button(store.t("export.copyClipboard")) { copyClipboard(ids) }
        Divider()
        if ids.count == 1 {
            Button(store.t("sidebar.rename")) { beginRename(sheet) }
        }
        Button(store.t("sidebar.delete"), role: .destructive) { store.deleteSheets(ids) }
    }

    /// IDs to operate on: the current multi-selection if the row is part of it,
    /// otherwise just the row itself.
    private func targetIDs(for id: UUID?) -> Set<UUID> {
        if let id {
            if store.selection.contains(id) && store.selection.count > 1 {
                return store.selection
            }
            return [id]
        }
        return store.selection
    }

    // MARK: - Rename

    private var renameAlertPresented: Binding<Bool> {
        Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
    }

    private func beginRename(_ sheet: AnswerSheet) {
        renamingID = sheet.id
        renameText = sheet.title
    }

    private func commitRename() {
        guard let id = renamingID else { return }
        store.renameSheet(id, to: renameText)
        renamingID = nil
    }

    // MARK: - Export actions

    private func exportExcel(_ ids: Set<UUID>) {
        store.exportSheetsToExcel(ids)
    }

    private func copyClipboard(_ ids: Set<UUID>) {
        store.copySheetsToClipboard(ids)
    }
}

/// A single sheet row in the sidebar.
private struct SidebarRow: View {
    @EnvironmentObject private var store: AppStore
    let sheet: AnswerSheet

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.title)
                    .lineLimit(1)
                Text(store.t("sidebar.questionCount", sheet.totalQuestions))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let seconds = sheet.mockExamElapsedSeconds {
                Text(MockExamTimerViewModel.format(seconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
