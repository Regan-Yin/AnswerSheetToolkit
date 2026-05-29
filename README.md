<div align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Answer Sheet Toolkit icon" />
  <h1>Answer Sheet Toolkit</h1>
  <p>A clean, keyboard-first macOS app for recording multiple-choice paper answers.</p>
</div>

---

## Overview

**Answer Sheet Toolkit** is a native macOS (SwiftUI) app for quickly recording the
answers from multiple-choice paper exams. It is built around a fast,
keyboard-driven answer grid, a configurable mock-exam timer, and clean export to
Excel and the clipboard.

## Features

- **Answer sheet management** — create, rename, delete, and switch between multiple sheets.
- **Keyboard-first grid** — type `A`–`D` (configurable) to fill answers; `Tab` / `Shift+Tab`
  move the highlight forward and back; `Delete` clears; `Esc` exits answering mode.
- **Smart layout** — set the total number of questions and the grid auto-fits the most
  "square" shape (e.g. `85` → 10 × 9 with a partly-filled last row). You can also set
  questions-per-row or rows directly. All fields are number-only.
- **Configurable answer choices** — restrict input to a subset such as A–D. The choice is
  snapshotted per sheet, so changing the setting only affects newly created sheets.
- **Mock exam mode** — count-up (stopwatch) or count-down timer with an editable
  `hours:minutes` duration and an optional start delay. The timer updates live and freezes
  on completion so you can see exactly how long you took.
- **Export** — one click to `.xlsx` or the clipboard (TSV), with in-app success/failure
  notifications. A custom dependency-free XLSX writer keeps the app lightweight.
- **Persistence** — sheets and settings are stored as JSON in Application Support.
- **Localization** — English and Simplified Chinese, switchable at runtime.
- **Theming** — System, Light, Dark, and Light Amber.

## Requirements

- macOS 14.0+
- Xcode 15+ (Swift 5.9+)

## Build & Run

```bash
git clone <your-repo-url>
cd AnswerSheetToolkit
open AnswerSheetToolkit.xcodeproj
```

Then select the **AnswerSheetToolkit** scheme and press **Run** (⌘R).

Or from the command line:

```bash
xcodebuild build -scheme AnswerSheetToolkit -destination 'platform=macOS'
```

## Tests

The project has comprehensive unit and UI tests (models, logic, services,
view models, and end-to-end keyboard flows):

```bash
xcodebuild test -scheme AnswerSheetToolkit -destination 'platform=macOS'
```

## Packaging for Distribution

Use the included script to build a Release `.app` and package it as both a
drag-to-Applications `.dmg` and a `.zip`:

```bash
./scripts/package.sh
```

Outputs land in `dist/`.

> **Gatekeeper note:** the build is unsigned. On another Mac, macOS will warn that the
> app is from an unidentified developer. The recipient can right-click the app →
> **Open** (once), or run:
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/AnswerSheetToolkit.app
> ```
>
> For frictionless distribution, sign with a **Developer ID** certificate and
> notarize the app with `notarytool`.

## Architecture

The app follows **MVVM** with a single coordinating `AppStore`:

- **Models** — `AppSettings`, `AnswerSheet`, `AnswerEntry`, `ThemeMode`, `LanguageMode`,
  `MockTimerMode`.
- **Logic** — pure, testable helpers (`AnswerValidator`, `GridNavigator`).
- **Services** — persistence, export (`XLSXWriter`, `ZipArchive`), clipboard,
  localization, theming.
- **ViewModels** — `AppStore`, `AnswerSheetEditorViewModel`, `MockExamTimerViewModel`,
  `SettingsViewModel`, `ExportViewModel`.
- **Views** — SwiftUI views plus a small AppKit `KeyCaptureView` for reliable
  `Tab` / `Shift+Tab` handling.

## Project Structure

```
AnswerSheetToolkit/            App source (Models, Logic, Services, ViewModels, Views, Resources)
AnswerSheetToolkitTests/       Unit tests
AnswerSheetToolkitUITests/     UI tests
scripts/package.sh             Build a .dmg + .zip for distribution
docs/SPEC.md                   Original product specification
```

## License

Released under the [MIT License](LICENSE).
