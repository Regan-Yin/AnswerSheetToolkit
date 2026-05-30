import XCTest
@testable import AnswerSheetToolkit

@MainActor
final class StoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AST_Tests_\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeStore() -> AppStore {
        AppStore(persistence: PersistenceService(directory: tempDir))
    }

    // MARK: Layout settings (total = rows × per-row)

    func testEditingRowsRecomputesTotal() {
        let store = makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setQuestionsPerRow(10)
        vm.setRows(8)
        XCTAssertEqual(vm.draft.defaultRows, 8)
        XCTAssertEqual(vm.draft.defaultQuestionsPerRow, 10)
        XCTAssertEqual(vm.draft.defaultTotalQuestions, 80)
    }

    func testEditingPerRowRecomputesTotal() {
        let store = makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setRows(10)
        vm.setQuestionsPerRow(5)
        XCTAssertEqual(vm.draft.defaultRows, 10)
        XCTAssertEqual(vm.draft.defaultQuestionsPerRow, 5)
        XCTAssertEqual(vm.draft.defaultTotalQuestions, 50)
    }

    func testEditingTotalDoesNotChangeRowsOrPerRow() {
        let store = makeStore()
        let vm = SettingsViewModel(store: store)
        vm.setRows(10)
        vm.setQuestionsPerRow(10) // total -> 100
        vm.setTotalQuestions(85)
        XCTAssertEqual(vm.draft.defaultTotalQuestions, 85)
        // Rows and per-row are untouched by editing total.
        XCTAssertEqual(vm.draft.defaultRows, 10)
        XCTAssertEqual(vm.draft.defaultQuestionsPerRow, 10)
    }

    // MARK: Create / answer entry

    func testCreateSheetEntersAnsweringAndFocusesQ1() {
        let store = makeStore()
        store.createSheet()
        XCTAssertEqual(store.sheets.count, 1)
        XCTAssertTrue(store.editor.isAnswering)
        XCTAssertEqual(store.editor.focusedIndex, 0)
        XCTAssertEqual(store.activeSheet?.totalQuestions, 100)
    }

    func testTypingLetterSavesUppercaseAndAdvances() {
        let store = makeStore()
        store.createSheet()
        store.editor.handleCharacter("a")
        XCTAssertEqual(store.activeSheet?.answers[0].answer, "A")
        XCTAssertEqual(store.editor.focusedIndex, 1)
    }

    func testTypingConsecutiveLetters() {
        let store = makeStore()
        store.createSheet()
        store.editor.handleCharacter("a")
        store.editor.handleCharacter("b")
        store.editor.handleCharacter("c")
        store.editor.handleCharacter("d")
        XCTAssertEqual(store.activeSheet?.answers[0].answer, "A")
        XCTAssertEqual(store.activeSheet?.answers[1].answer, "B")
        XCTAssertEqual(store.activeSheet?.answers[2].answer, "C")
        XCTAssertEqual(store.activeSheet?.answers[3].answer, "D")
        XCTAssertEqual(store.editor.focusedIndex, 4)
    }

    func testInvalidKeysIgnored() {
        let store = makeStore()
        store.createSheet()
        XCTAssertFalse(store.editor.handleCharacter("1"))
        XCTAssertFalse(store.editor.handleCharacter("@"))
        XCTAssertNil(store.activeSheet?.answers[0].answer)
        XCTAssertEqual(store.editor.focusedIndex, 0)
    }

    func testTabSkipsLeavingNilAndAdvances() {
        let store = makeStore()
        store.createSheet()
        store.editor.focusedIndex = 4 // Q5
        store.editor.moveNext()
        XCTAssertNil(store.activeSheet?.answers[4].answer) // Q5 still nil
        XCTAssertEqual(store.editor.focusedIndex, 5)
    }

    func testShiftTabMovesBack() {
        let store = makeStore()
        store.createSheet()
        store.editor.focusedIndex = 5 // Q6
        store.editor.movePrevious()
        XCTAssertEqual(store.editor.focusedIndex, 4) // Q5
    }

    func testDeleteClearsCurrentAnswer() {
        let store = makeStore()
        store.createSheet()
        store.editor.handleCharacter("a") // Q1 = A, focus -> Q2
        store.editor.focusedIndex = 0
        store.editor.clearCurrent()
        XCTAssertNil(store.activeSheet?.answers[0].answer)
    }

    func testFinalQuestionDoesNotMoveBeyondBounds() {
        let store = makeStore()
        store.createSheet()
        store.editor.focusedIndex = 99 // Q100
        store.editor.handleCharacter("a")
        XCTAssertEqual(store.activeSheet?.answers[99].answer, "A")
        XCTAssertEqual(store.editor.focusedIndex, 99) // stays in bounds
    }

    func testEscapeExitsAnsweringMode() {
        let store = makeStore()
        store.createSheet()
        store.editor.exitAnsweringMode(reason: .escape)
        XCTAssertFalse(store.editor.isAnswering)
    }

    // MARK: Answer-choice restriction

    func testAnswerChoiceRestrictionEnforced() {
        let store = makeStore() // default 4 choices (A–D)
        store.createSheet()
        XCTAssertTrue(store.editor.handleCharacter("a"))   // A allowed
        XCTAssertFalse(store.editor.handleCharacter("e"))  // E rejected
        XCTAssertFalse(store.editor.handleCharacter("w"))  // W rejected
        XCTAssertEqual(store.activeSheet?.answers[0].answer, "A")
        // Focus advanced only once (after the accepted "A").
        XCTAssertEqual(store.editor.focusedIndex, 1)
        XCTAssertNil(store.activeSheet?.answers[1].answer)
    }

    func testAnswerChoiceSnapshotUnchangedAfterSettingsChange() {
        let store = makeStore()
        store.createSheet()
        let oldID = store.activeSheetID!

        var s = store.settings
        s.defaultAnswerOptionCount = 6 // A–F
        store.updateSettings(s)

        // Old sheet keeps 4 (A–D).
        let oldSheet = store.sheets.first { $0.id == oldID }!
        XCTAssertEqual(oldSheet.allowedAnswerCount, 4)

        // New sheet uses 6 and now accepts E/F.
        store.createSheet()
        XCTAssertEqual(store.activeSheet?.allowedAnswerCount, 6)
        XCTAssertTrue(store.editor.handleCharacter("f"))
        XCTAssertEqual(store.activeSheet?.answers[0].answer, "F")
    }

    // MARK: Layout snapshot

    func testLayoutSnapshotUnchangedAfterSettingsChange() {
        let store = makeStore()
        store.createSheet()
        let oldID = store.activeSheetID!

        var newSettings = store.settings
        newSettings.defaultTotalQuestions = 120
        newSettings.defaultQuestionsPerRow = 12
        store.updateSettings(newSettings)

        let oldSheet = store.sheets.first { $0.id == oldID }!
        XCTAssertEqual(oldSheet.totalQuestions, 100)
        XCTAssertEqual(oldSheet.questionsPerRow, 10)

        store.createSheet()
        XCTAssertEqual(store.activeSheet?.totalQuestions, 120)
        XCTAssertEqual(store.activeSheet?.questionsPerRow, 12)
    }

    // MARK: Sidebar focus rule + timer

    func testSidebarClickStopsTimerAndExitsAnswering() {
        let store = makeStore()
        store.setMockExamMode(true)
        var current = Date(timeIntervalSince1970: 100)
        store.timer.now = { current }
        store.createSheet() // 0s lead-in -> timing begins immediately at t=100
        XCTAssertTrue(store.timer.isRunning)

        current = Date(timeIntervalSince1970: 130) // +30s
        store.sidebarInteraction()

        XCTAssertFalse(store.editor.isAnswering)
        XCTAssertTrue(store.timer.isCompleted)
        XCTAssertEqual(store.activeSheet?.mockExamElapsedSeconds, 30)
    }

    func testTimerStopsAfterFinalAnswer() {
        let store = makeStore()
        store.setMockExamMode(true)
        var current = Date(timeIntervalSince1970: 0)
        store.timer.now = { current }
        store.createSheet() // timing begins at t=0
        store.editor.focusedIndex = 99    // jump to final
        current = Date(timeIntervalSince1970: 12)
        store.editor.handleCharacter("b") // final answer at t=12
        XCTAssertTrue(store.timer.isCompleted)
        XCTAssertEqual(store.activeSheet?.mockExamElapsedSeconds, 12)
        XCTAssertNotNil(store.activeSheet?.mockExamCompletedAt)
    }

    func testCountdownCancelledBySidebarClick() {
        let store = makeStore()
        var s = store.settings
        s.mockExamCountdownSeconds = 5
        store.updateSettings(s)
        store.setMockExamMode(true)
        store.createSheet()
        XCTAssertTrue(store.timer.isCountingDown)

        store.sidebarInteraction()
        XCTAssertFalse(store.timer.isCountingDown)
        XCTAssertFalse(store.editor.isAnswering)
        // No elapsed recorded because timing never started.
        XCTAssertNil(store.activeSheet?.mockExamElapsedSeconds)
    }

    // MARK: Delete

    func testDeleteActiveSelectsAnother() {
        let store = makeStore()
        store.createSheet()
        let first = store.activeSheetID!
        store.createSheet()
        let second = store.activeSheetID!
        store.deleteSheets([second])
        XCTAssertEqual(store.activeSheetID, first)
        XCTAssertEqual(store.sheets.count, 1)
    }

    func testDeleteAllShowsEmptyState() {
        let store = makeStore()
        store.createSheet()
        store.deleteSheets(Set(store.sheets.map { $0.id }))
        XCTAssertNil(store.activeSheetID)
        XCTAssertTrue(store.sheets.isEmpty)
    }

    // MARK: Persistence

    func testPersistenceRoundTrip() {
        let persistence = PersistenceService(directory: tempDir)
        let store = AppStore(persistence: persistence)
        store.createSheet()
        store.editor.handleCharacter("a")
        store.renameSheet(store.activeSheetID!, to: "My Exam")
        var s = store.settings
        s.defaultTotalQuestions = 120
        store.updateSettings(s)

        // New store from same directory should load persisted data.
        let reloaded = AppStore(persistence: PersistenceService(directory: tempDir))
        XCTAssertEqual(reloaded.sheets.count, 1)
        XCTAssertEqual(reloaded.sheets.first?.title, "My Exam")
        XCTAssertEqual(reloaded.sheets.first?.answers[0].answer, "A")
        XCTAssertEqual(reloaded.settings.defaultTotalQuestions, 120)
    }
}
