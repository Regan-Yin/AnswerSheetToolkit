import Foundation

/// Builds export representations (rows, TSV, sanitized names) from answer sheets.
///
/// The grid layout is reproduced exactly: each question becomes two columns
/// (number, answer). With `questionsPerRow == 10`, each row has 20 columns.
/// Unanswered questions export as `N/A`. Uses each sheet's own snapshot layout.
enum ExportService {
    /// Produces the 2D table for a sheet using its snapshot `questionsPerRow`.
    ///
    /// This always honors the configured questions-per-row, independent of how many
    /// columns the on-screen grid happens to show for the current window size.
    /// Each output row contains `questionsPerRow * 2` cells: `[num, ans, num, ans, ...]`.
    /// The final row may contain fewer questions if `totalQuestions` is not divisible
    /// by `questionsPerRow`.
    static func tableRows(for sheet: AnswerSheet) -> [[String]] {
        var sheet = sheet
        sheet.normalizeAnswers()
        let perRow = max(1, sheet.questionsPerRow)
        var rows: [[String]] = []
        var current: [String] = []
        for entry in sheet.answers {
            current.append(String(entry.questionNumber))
            current.append(entry.exportValue)
            if current.count == perRow * 2 {
                rows.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }

    /// Tab-separated representation of a single sheet (no trailing newline).
    static func tsv(for sheet: AnswerSheet) -> String {
        tableRows(for: sheet)
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
    }

    /// TSV for multiple sheets, separated by a blank line and a title line per sheet.
    static func tsv(for sheets: [AnswerSheet]) -> String {
        sheets.map { sheet in
            "\(sheet.title)\n\(tsv(for: sheet))"
        }
        .joined(separator: "\n\n")
    }

    // MARK: - Sanitization

    /// Characters Excel forbids in worksheet names.
    private static let invalidSheetNameChars = CharacterSet(charactersIn: "[]:*?/\\")

    /// Sanitizes a title into a valid Excel worksheet name:
    /// - removes invalid characters `[ ] : * ? / \`
    /// - trims leading/trailing single quotes and whitespace
    /// - truncates to Excel's 31-character limit
    /// - falls back to "Sheet" when empty
    static func sanitizedWorksheetName(_ title: String) -> String {
        var result = String(
            title.unicodeScalars
                .filter { !invalidSheetNameChars.contains($0) }
                .map(Character.init)
        )
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("'") { result.removeFirst() }
        while result.hasSuffix("'") { result.removeLast() }
        if result.count > 31 {
            result = String(result.prefix(31))
        }
        if result.trimmingCharacters(in: .whitespaces).isEmpty {
            result = "Sheet"
        }
        return result
    }

    /// Makes worksheet names unique (Excel requires uniqueness, case-insensitive).
    static func uniqueWorksheetNames(for titles: [String]) -> [String] {
        var used = Set<String>()
        var output: [String] = []
        for title in titles {
            let base = sanitizedWorksheetName(title)
            var candidate = base
            var counter = 2
            while used.contains(candidate.lowercased()) {
                let suffix = "_\(counter)"
                let trimmedBase = String(base.prefix(31 - suffix.count))
                candidate = trimmedBase + suffix
                counter += 1
            }
            used.insert(candidate.lowercased())
            output.append(candidate)
        }
        return output
    }

    /// Sanitizes a string for use as a file name (no path separators / illegal chars).
    static func sanitizedFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.newlines)
            .union(.controlCharacters)
        var result = String(
            name.unicodeScalars
                .filter { !illegal.contains($0) }
                .map(Character.init)
        )
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // Avoid names that are only dots.
        if result.allSatisfy({ $0 == "." }) { result = "" }
        if result.isEmpty { result = "AnswerSheet" }
        if result.count > 200 { result = String(result.prefix(200)) }
        return result
    }

    /// Timestamp used in default file names: `YYYY-MM-DD_HH-mm`.
    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter.string(from: date)
    }

    /// Default file name for a single-sheet export.
    static func singleFileName(title: String, date: Date = Date()) -> String {
        "\(sanitizedFileName(title))_\(timestamp(date)).xlsx"
    }

    /// Default file name for a multi-sheet export.
    static func multiFileName(date: Date = Date()) -> String {
        "AnswerSheets_\(timestamp(date)).xlsx"
    }
}
