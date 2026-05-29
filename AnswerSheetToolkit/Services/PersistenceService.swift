import Foundation

/// Reads and writes app data as JSON files under Application Support.
///
/// Two files are stored:
/// - `settings.json`
/// - `answerSheets.json`
///
/// The directory can be overridden (used by tests for isolation).
final class PersistenceService {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var sheetsURL: URL { directory.appendingPathComponent("answerSheets.json") }
    var settingsURL: URL { directory.appendingPathComponent("settings.json") }

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("AnswerSheetToolkit", isDirectory: true)
        }
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        ensureDirectory()
    }

    private func ensureDirectory() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Sheets

    func loadSheets() -> [AnswerSheet] {
        guard let data = try? Data(contentsOf: sheetsURL) else { return [] }
        guard var sheets = try? decoder.decode([AnswerSheet].self, from: data) else { return [] }
        for i in sheets.indices { sheets[i].normalizeAnswers() }
        return sheets
    }

    func saveSheets(_ sheets: [AnswerSheet]) {
        ensureDirectory()
        guard let data = try? encoder.encode(sheets) else { return }
        try? data.write(to: sheetsURL, options: .atomic)
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings.validated()
    }

    func saveSettings(_ settings: AppSettings) {
        ensureDirectory()
        guard let data = try? encoder.encode(settings.validated()) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }
}
