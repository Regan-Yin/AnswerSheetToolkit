import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Writes TSV text to the system pasteboard. TSV pastes cleanly into Excel,
/// Numbers, Google Sheets, and Word.
enum ClipboardService {
    static func copy(_ text: String) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #endif
    }

    static func copySheets(_ sheets: [AnswerSheet]) {
        let text = sheets.count == 1
            ? ExportService.tsv(for: sheets[0])
            : ExportService.tsv(for: sheets)
        copy(text)
    }
}
