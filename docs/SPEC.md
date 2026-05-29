# macOS Answer Sheet Toolkit — Product & Development Specification

## 1. Product Goal

Build a clean native macOS application that helps the user create, manage, fill, export, and review multiple-choice answer sheets.

Each answer sheet represents one exam paper.

Default paper layout:

- 100 questions total
- 10 questions per row
- Each question accepts exactly one alphabetic answer
- Answers are automatically capitalized
- Empty/skipped questions are recorded as `N/A`
- User can export one or multiple answer sheets to Excel or copy a view-matching table format to the clipboard

The app should feel fast, keyboard-first, clean, and minimal.

---

## 2. Recommended Tech Stack

Use a native macOS app:

- Language: Swift
- UI: SwiftUI
- Persistence: SwiftData or local JSON storage
- Export:
  - Clipboard: TSV table format
  - Excel: `.xlsx` export using a lightweight internal XLSX writer or a dedicated export module
- Platform: macOS 14+
- Architecture: MVVM

Recommended app structure:

```text
AnswerSheetToolkit/
  App/
    AnswerSheetToolkitApp.swift
  Models/
    AnswerSheet.swift
    AnswerEntry.swift
    AppSettings.swift
    ThemeMode.swift
    LanguageMode.swift
  ViewModels/
    AnswerSheetListViewModel.swift
    AnswerSheetEditorViewModel.swift
    SettingsViewModel.swift
    MockExamTimerViewModel.swift
    ExportViewModel.swift
  Views/
    MainView.swift
    SidebarView.swift
    AnswerGridView.swift
    AnswerCellView.swift
    TopToolbarView.swift
    SettingsView.swift
    ExportMenuView.swift
  Services/
    PersistenceService.swift
    ExportService.swift
    ClipboardService.swift
    LocalizationService.swift
    ThemeService.swift
  Tests/
    AnswerSheetToolkitTests/
```

---

## 3. Core Objects

### 3.1 AnswerSheet

Represents one paper answer sheet.

Fields:

```swift
struct AnswerSheet: Identifiable, Codable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    var totalQuestions: Int
    var questionsPerRow: Int

    var answers: [AnswerEntry]

    var mockExamEnabledAtCreation: Bool
    var mockExamElapsedSeconds: Int?
    var mockExamStartedAt: Date?
    var mockExamCompletedAt: Date?

    var languageSnapshot: LanguageMode?
    var themeSnapshot: ThemeMode?
}
```

Rules:

- `totalQuestions` and `questionsPerRow` are locked when the answer sheet is created.
- Later settings changes must not modify existing answer sheets.
- The answers array should always contain exactly `totalQuestions` entries.
- Question numbers are 1-based for display.
- Internal array index is 0-based.

---

### 3.2 AnswerEntry

```swift
struct AnswerEntry: Identifiable, Codable {
    var id: UUID
    var questionNumber: Int
    var answer: String?
}
```

Rules:

- Valid answer is a single capital alphabetic character from `A` to `Z`.
- Empty or skipped answer is stored internally as `nil`.
- Export should display `N/A` for `nil`.
- UI may display an empty cell for unanswered questions, but export must use `N/A`.

---

### 3.3 AppSettings

```swift
struct AppSettings: Codable {
    var defaultTotalQuestions: Int
    var defaultQuestionsPerRow: Int
    var exportFolderURL: URL?
    var language: LanguageMode
    var theme: ThemeMode
    var mockExamCountdownSeconds: Int
}
```

Defaults:

```text
defaultTotalQuestions = 100
defaultQuestionsPerRow = 10
language = English
theme = Follow System
mockExamCountdownSeconds = 0
exportFolderURL = nil
```

Validation:

- Total questions: minimum 1, maximum 300
- Questions per row: minimum 1, maximum 25
- If total questions is not divisible by questions per row, the final row can be partially filled.
- Export folder can be selected through native macOS folder picker.

---

## 4. Main App Layout

### 4.1 Main Window

The main window has three primary areas:

```text
┌─────────────────────────────────────────────────────────────┐
│ Top Toolbar                                                  │
├───────────────┬─────────────────────────────────────────────┤
│ Sidebar       │ Answer Sheet Grid                           │
│               │                                             │
│ Sheet List    │ 1  2  3  4  5  6  7  8  9  10              │
│               │ 11 12 13 14 15 16 17 18 19 20              │
│               │ ...                                         │
└───────────────┴─────────────────────────────────────────────┘
```

Top toolbar includes:

- Sidebar show/hide button
- New answer sheet button
- Settings button
- Mock Exam Mode switch
- Countdown selector or setting indicator
- Timer display in top-right corner
- Export button or contextual menu

---

## 5. Sidebar Requirements

### 5.1 Sidebar Behaviours

The left sidebar stores all answer sheets.

User can:

- Create answer sheet
- Select answer sheet
- Rename answer sheet
- Delete answer sheet
- Right-click one sheet for export/copy/delete/rename
- Multi-select sheets for batch export/copy
- Hide/show sidebar

### 5.2 Important Focus Rule

When the user clicks anywhere in the sidebar:

- Exit answering mode
- Remove answer grid keyboard capture
- Stop active countdown
- Stop active mock exam timer
- Disable alphabet-entry auto-advance until the user clicks/focuses back into the answer grid

This is critical.

Implementation requirement:

```swift
editorViewModel.exitAnsweringMode(reason: .sidebarInteraction)
timerViewModel.stopAllTiming()
```

---

## 6. Answer Grid Requirements

### 6.1 Default Grid

Default new answer sheet:

- 100 questions
- 10 questions per row
- 10 rows total

Each cell should show:

```text
Question number + answer input box
```

Example:

```text
1 [A]   2 [C]   3 [B]   4 [blank] ...
```

Recommended visual style:

- Compact
- Clear question number
- Large enough answer box
- Selected cell has obvious focus ring
- Unanswered cells remain visually clean
- Avoid clutter

---

### 6.2 New Sheet Auto-Focus

When the user creates a new answer sheet:

- Automatically select the new sheet
- Automatically focus question 1
- Enter answering mode
- If Mock Exam Mode is ON:
  - Start countdown if countdown is configured
  - Start timer after countdown finishes or when first answer is entered, depending on implementation choice
  - Preferred: countdown first, then timer starts when first valid answer is entered

---

### 6.3 Keyboard Entry Behaviour

When in answering mode:

Allowed keys:

- `A-Z` or `a-z`
- `Tab`
- `Shift + Tab`
- Delete / Backspace for clearing current answer
- Escape to exit answering mode

Input rules:

- When user types any alphabet:
  - Convert it to uppercase
  - Save it to current question
  - Immediately move focus to the next question
- If user types a second letter while focus already moved, it applies to the new question.
- Only one letter is allowed per question.
- Numeric input and symbols should be ignored.
- Pasted text should not mass-fill unless explicitly implemented later. For v1, ignore paste into grid cells or only take first valid letter.

Navigation rules:

- `Tab`: move to next question without answering current question
- `Shift + Tab`: move to previous question
- Skipped unanswered questions are stored as `nil` and exported as `N/A`
- Reaching the final question:
  - If user enters an answer for the final question, mark sheet as completed
  - In Mock Exam Mode, stop timer immediately after final answer is entered
  - Stay focused on final cell or exit answering mode; preferred: stay focused but stop timer

---

### 6.4 Mouse Behaviour in Grid

When user clicks an answer cell:

- Enter answering mode
- Focus selected question
- In Mock Exam Mode:
  - Do not restart a completed timer
  - If timer was stopped because user clicked sidebar, user may resume by focusing the grid and pressing a Resume button or entering an answer
  - Preferred v1: clicking the grid resumes answering mode, but the timer only resumes if user clicks explicit “Resume Timer”

This prevents accidental time changes.

---

## 7. Mock Exam Mode

### 7.1 Switch

Mock Exam Mode is controlled by a switch in the top-right toolbar.

States:

- OFF: normal answer sheet editing
- ON: mock exam mode enabled

User can turn it on/off easily.

### 7.2 Mock Exam Timer

When Mock Exam Mode is ON:

- Show timer at top-right
- Timer records elapsed time from start of answering to completion
- Timer starts when:
  - Countdown finishes, and
  - User enters first answer or explicitly clicks Start
- Timer stops when:
  - Final question is answered
  - User clicks sidebar
  - User exits answering mode
  - User manually stops the timer
- Timer value is saved to the answer sheet

Timer display format:

```text
00:00:00
```

### 7.3 Countdown Option

Settings should allow countdown duration:

- 0 seconds
- 3 seconds
- 5 seconds
- 10 seconds
- 30 seconds
- 60 seconds

Toolbar should show countdown status when active.

Example:

```text
Starting in 5...
```

During countdown:

- Answer grid should be locked
- Sidebar click cancels countdown
- Mock timer has not started yet

---

## 8. Settings Page

Settings page should include:

### 8.1 Question Layout

Fields:

- Total questions
- Questions per row
- Computed row count preview

Example:

```text
Total Questions: 100
Questions Per Row: 10
Rows: 10
```

Important rule:

- Settings changes only apply to newly created answer sheets.
- Existing answer sheets must keep their original layout.
- Do not overwrite or reshape previous answer sheets.

Show helper text:

```text
Changes to question layout will only apply to new answer sheets. Existing sheets will keep their original layout.
```

### 8.2 Export Folder

User can choose export folder.

If no folder is selected:

- Use macOS save panel for each export, or
- Default to Documents/AnswerSheetExports

Preferred v1:

- If export folder exists, export directly there.
- If not, ask user to choose destination.

### 8.3 Language

Supported languages:

- English
- 简体中文

All major UI labels must be localized.

### 8.4 Theme

Supported theme modes:

- Follow System
- Light
- Dark
- Light Amber

Default:

```text
Follow System
```

Light Amber theme:

- Warm background
- Clean high-contrast text
- Avoid over-saturated colors
- Should still support accessibility contrast

---

## 9. Export Requirements

### 9.1 Single Sheet Export

User can right-click one answer sheet and choose:

- Export to Excel
- Copy table to clipboard
- Rename
- Delete

### 9.2 Multi-Sheet Export

User can select multiple sheets in sidebar and right-click:

- Export selected sheets to Excel
- Copy selected sheets to clipboard

Excel behaviour:

- If exporting one sheet:
  - Create one `.xlsx` file with one worksheet
- If exporting multiple sheets:
  - Preferred: create one `.xlsx` file with multiple worksheets
  - Each worksheet name should use the answer sheet title
  - Sanitize worksheet names for Excel compatibility

### 9.3 Export Format

The export/copy format should exactly match the user’s view layout.

Example for 100 questions and 10 per row:

```text
1	A	2	C	3	B	4	N/A	5	D	6	A	7	B	8	C	9	D	10	A
11	B	12	A	13	C	14	D	15	N/A	16	B	17	A	18	C	19	D	20	B
...
```

Each question should export as:

```text
Question Number | Answer
```

Since the visual layout has 10 questions per row, the exported table should have 20 columns:

```text
Q1 | A1 | Q2 | A2 | ... | Q10 | A10
```

For clipboard:

- Use TSV format so it pastes cleanly into Excel, Numbers, Google Sheets, or Word.
- Empty answers become `N/A`.

For Excel:

- Preserve same layout.
- Use bold formatting for question numbers if possible.
- Use clean borders.
- Autosize columns if possible.
- Freeze nothing by default.

### 9.4 File Naming

Default file name:

```text
AnswerSheets_YYYY-MM-DD_HH-mm.xlsx
```

Single sheet export:

```text
SheetTitle_YYYY-MM-DD_HH-mm.xlsx
```

Sanitize invalid filename characters.

---

## 10. Data Persistence

The app must store answer sheets locally and safely.

Requirements:

- Answer sheets persist after app restart
- Settings persist after app restart
- No data loss when switching sheets
- Autosave after each answer entry
- Autosave after rename
- Autosave after delete
- Autosave after settings change

Recommended storage:

- SwiftData if using macOS 14+
- Otherwise JSON files inside Application Support folder

Recommended folder:

```text
~/Library/Application Support/AnswerSheetToolkit/
```

Data files:

```text
settings.json
answerSheets.json
```

or SwiftData persistent container.

---

## 11. Validation & Edge Cases

Handle these cases:

1. User creates a new sheet with 100 questions and 10 per row.
2. User changes setting to 120 questions and 12 per row.
3. Old 100-question sheet remains unchanged.
4. New sheet uses 120-question layout.
5. User skips question using Tab.
6. Skipped question exports as `N/A`.
7. User types lowercase `a`; app saves `A`.
8. User types number or symbol; app ignores it.
9. User enters answer on final question in mock mode; timer stops.
10. User clicks sidebar during countdown; countdown cancels.
11. User clicks sidebar during timer; timer stops.
12. User hides sidebar; current sheet remains active.
13. User multi-selects sheets and exports.
14. User deletes selected sheet; app selects next available sheet.
15. User deletes all sheets; grid shows empty state.
16. User renames sheet to a duplicate name; app allows it but uses unique export filename.
17. User renames sheet with invalid Excel worksheet characters; export sanitizes name.
18. App is quit during active answer sheet editing; answers are saved.
19. Theme follows macOS system setting by default.
20. Language switch updates UI labels.

---

## 12. Accessibility Requirements

- Full keyboard navigation support
- Strong visible focus state
- Sufficient contrast in all themes
- VoiceOver labels for answer cells:

```text
Question 1, answer A
Question 2, unanswered
```

- Buttons and switches must have accessible labels.

---

## 13. MVP Scope

Must-have for v1:

- Native macOS app
- Sidebar sheet list
- Create / rename / delete answer sheets
- Hide/show sidebar
- Answer grid
- Auto-capitalized alphabet entry
- Auto-advance
- Tab / Shift+Tab navigation
- Empty answer as `N/A`
- Mock Exam Mode switch
- Countdown option
- Timer
- Settings page
- Language: English / 简体中文
- Theme: Follow System / Light / Dark / Light Amber
- Export one or multiple sheets to Excel
- Copy one or multiple sheets to clipboard
- Persistent local storage
- Unit tests for data logic
- UI tests for answer entry flow

Out of scope for v1:

- Cloud sync
- iCloud storage
- User accounts
- Answer key grading
- OCR
- PDF import
- Bulk paste answer filling
- Mobile app
- Web app

---

## 14. Suggested Regression Tests

### 14.1 Unit Tests

1. Create default sheet:
  - Should have 100 questions.
  - Should have 10 questions per row.
  - Should generate 100 answer entries.
2. Answer validation:
  - Input `a` should become `A`.
  - Input `z` should become `Z`.
  - Input `1`, `@`, or whitespace should be ignored.
3. Auto-advance:
  - After answering Q1, focus moves to Q2.
  - After answering Q99, focus moves to Q100.
  - After answering Q100, focus remains within bounds.
4. Tab navigation:
  - `Tab` from Q1 moves to Q2.
  - `Shift + Tab` from Q2 moves to Q1.
  - `Shift + Tab` from Q1 stays at Q1.
5. Skipped answer:
  - Empty answer stores as `nil`.
  - Export displays `N/A`.
6. Layout snapshot:
  - Existing 100/10 sheet remains 100/10 after settings are changed.
  - New sheet after settings change uses the new layout.
7. Export shape:
  - 100 questions with 10 per row exports 10 rows and 20 columns.
  - 120 questions with 12 per row exports 10 rows and 24 columns.
  - 101 questions with 10 per row exports 11 rows, with final row partially filled.
8. Excel sanitization:
  - Invalid worksheet characters are removed or replaced.
  - Worksheet names are truncated to Excel’s limit if necessary.
  - Duplicate worksheet names are made unique.
9. Timer:
  - Timer starts correctly.
  - Timer stops correctly.
  - Timer stops when final question is answered.
  - Timer stops when sidebar is clicked.
  - Countdown cancellation works.
10. Persistence:
  - Created sheet persists.
  - Edited answers persist.
  - Renamed title persists.
  - Settings persist.

---

### 14.2 UI Tests

1. Create a new sheet:
  - Sheet appears in sidebar.
  - Q1 is focused automatically.
2. Fast answer entry:
  - Type `abcd`.
  - Q1 = A, Q2 = B, Q3 = C, Q4 = D.
3. Skip and return:
  - Press `Tab` on Q5.
  - Q5 remains blank.
  - Press `Shift + Tab`.
  - Focus returns to Q5.
4. Sidebar interruption:
  - Start mock exam timer.
  - Click sidebar.
  - Timer stops.
  - Answering mode exits.
5. Countdown interruption:
  - Enable 5-second countdown.
  - Start mock exam.
  - Click sidebar.
  - Countdown cancels.
6. Final question timer stop:
  - Enable mock mode.
  - Fill final question.
  - Timer stops.
7. Export:
  - Right-click one sheet.
  - Export and copy menu items are visible.
  - Multi-select sheets.
  - Batch export option is visible.
8. Theme switch:
  - Switch to Light.
  - Switch to Dark.
  - Switch to Light Amber.
  - Switch to Follow System.
9. Language switch:
  - Switch to English.
  - Switch to 简体中文.
  - Major UI labels update.

