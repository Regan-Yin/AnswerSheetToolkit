import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Handles exporting sheets to `.xlsx` and copying to the clipboard.
///
/// Resolves a destination: uses the configured export folder if set, otherwise shows
/// a save panel. Never overwrites an existing file without user confirmation.
@MainActor
final class ExportViewModel: ObservableObject {
    enum ExportResult: Equatable {
        case success(URL)
        case cancelled
        case failure(String)
    }

    /// Copies one or more sheets to the clipboard as TSV.
    func copyToClipboard(_ sheets: [AnswerSheet]) {
        ClipboardService.copySheets(sheets)
    }

    /// Exports sheets to a single `.xlsx` workbook (one worksheet per sheet).
    @discardableResult
    func exportToExcel(_ sheets: [AnswerSheet], settings: AppSettings) -> ExportResult {
        guard !sheets.isEmpty else { return .cancelled }
        let data = XLSXWriter.build(sheets: sheets)
        let suggestedName = sheets.count == 1
            ? ExportService.singleFileName(title: sheets[0].title)
            : ExportService.multiFileName()

        guard let destination = resolveDestination(suggestedName: suggestedName, folder: settings.exportFolderURL) else {
            return .cancelled
        }
        do {
            try data.write(to: destination, options: .atomic)
            return .success(destination)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Destination resolution

    private func resolveDestination(suggestedName: String, folder: URL?) -> URL? {
        #if canImport(AppKit)
        if let folder {
            let candidate = folder.appendingPathComponent(suggestedName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                // Ask the user before overwriting.
                if confirmOverwrite(name: suggestedName) {
                    return candidate
                } else {
                    return promptSavePanel(suggestedName: suggestedName, directory: folder)
                }
            }
            return candidate
        }
        return promptSavePanel(suggestedName: suggestedName, directory: nil)
        #else
        return nil
        #endif
    }

    #if canImport(AppKit)
    private func promptSavePanel(suggestedName: String, directory: URL?) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = []
        panel.canCreateDirectories = true
        if let directory { panel.directoryURL = directory }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func confirmOverwrite(name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = name
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("export.replace", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("common.cancel", comment: ""))
        return alert.runModal() == .alertFirstButtonReturn
    }
    #endif
}
