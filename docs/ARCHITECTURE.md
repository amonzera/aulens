# Aulens Architecture Map

This document maps the current Aulens implementation, technology choices, runtime flows, and architecture quality. `AGENTS.md` remains the canonical instruction file for AI agents and development rules.

## Executive Assessment

Aulens is a solid local-first Flutter application for its current scope: class schedules, photo capture, on-device OCR, local persistence, searchable notes, and timeline browsing. The architecture is pragmatic rather than over-engineered, which is appropriate for a single-user app that is still evolving.

State-of-the-art strengths:

- Local-first design avoids backend availability, privacy, and sync complexity.
- Feature-based folder structure is easy for agents and developers to navigate.
- Provider/ChangeNotifier is simple and adequate for the current state graph.
- SQLite persistence has migrations and cascade rules instead of ad hoc file state.
- OCR is asynchronous and failure-tolerant.
- Heavy note text is excluded from timeline/list metadata loading.
- Thumbnail decoding uses `cacheWidth` where list thumbnails are rendered.
- Baseline tests now cover time matching, nullable note updates, and SQLite search.

Production gaps:

- Android package identity and release signing still use template/debug defaults.
- Web builds compile, but camera/OCR workflows are mobile-first; web should be treated as compile validation unless explicitly supported.
- Localization files exist, but most UI strings are still hardcoded.
- Search uses SQLite `LIKE`; this is fine for small local datasets, but SQLite FTS would scale better.
- Navigation is direct `Navigator.push`; this is acceptable now, but named routes or `go_router` would help once deep links or larger flows appear.
- `DatabaseService` is a singleton around raw SQL; it is simple, but a typed database layer can become worthwhile if migrations and query complexity grow.
- Class mode/camera behavior needs physical mobile testing because key dependencies are platform-specific.

Conclusion: keep the current KISS architecture, but treat Android identity/signing, mobile test environment, localization, search indexing, and platform support boundaries as the next production-readiness work.

## Runtime Map

```text
main.dart
  └─ MultiProvider
      ├─ DatabaseService
      ├─ ScheduleService
      ├─ NotesService
      ├─ SettingsService
      ├─ ScheduleProvider
      ├─ SettingsProvider
      ├─ NotesProvider
      └─ ClassModeController

Bottom navigation
  ├─ SchedulePage
  ├─ NotesPage
  ├─ CameraPage
  └─ SearchPage

Capture flow
  CameraPage
    ├─ PermissionService
    ├─ CameraService.capturePhoto()
    ├─ NotesProvider.addPhotoNote()
    ├─ CameraService.enqueueBackgroundOcr()
    ├─ OcrService.extractText()
    └─ NotesProvider.updateOcrText()

Class detection flow
  Timer in main.dart
    ├─ ScheduleProvider.getCurrentClass()
    ├─ TimeUtils.matchEntryForTimestamp()
    ├─ ClassModeController
    └─ ClassModePage

Persistence flow
  Providers
    └─ Feature services
        └─ DatabaseService
            └─ SQLite database: aulens.db
```

## Source Layout

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | App bootstrap, provider wiring, bottom navigation, class-mode timer, quick-note sheet. |
| `lib/core/constants` | App constants such as DB name/version, image directory, weekday labels, grace defaults. |
| `lib/core/theme` | Material 3 light/dark themes. |
| `lib/core/utils` | Time parsing/matching helpers used by class detection and session grouping. |
| `lib/shared/database` | SQLite schema, migrations, and CRUD/query operations. |
| `lib/shared/providers` | In-memory state and UI-facing mutations for notes, schedule, settings, and class-mode prompt state. |
| `lib/shared/services` | Shared settings persistence. |
| `lib/shared/widgets` | Reusable snackbars and permission dialogs. |
| `lib/features/camera` | Capture flow, image persistence, permission handling, and ML Kit OCR orchestration. |
| `lib/features/class_mode` | Full-screen active-class capture/note entry flow. |
| `lib/features/notes` | Notes list, detail view, full-screen photo viewer, text note flows, note model and service. |
| `lib/features/schedule` | Subject/schedule CRUD, archive/restore behavior, schedule cards, schedule models and service. |
| `lib/features/search` | Live database-backed note search UI. |
| `lib/features/settings` | Class-detection grace windows and gallery-save preference. |
| `lib/features/timeline` | Class session and note grouping UI/models. |
| `lib/features/export` | Timeline PDF generation and file export. |
| `test/` | Baseline behavior tests. |

## Technology Inventory

| Technology | Current spec/source | Used for | Notes |
| --- | --- | --- | --- |
| Flutter | `sdk: ^3.9.0`; observed Flutter 3.41.6 | Cross-platform UI/runtime. | Primary target should be Android/mobile until platform support is explicitly broadened. |
| Dart | observed Dart 3.11.4 | App language and tests. | Keep code formatted with `dart format`. |
| Android Gradle defaults | Flutter-managed `compileSdk` 36, `targetSdk` 36, `minSdk` 24 in the observed Flutter toolchain. | Android build configuration. | Project currently delegates these values to Flutter in `android/app/build.gradle.kts`. |
| Material 3 | Flutter SDK | App visual system. | `AppTheme` defines light/dark color schemes and component defaults. |
| provider | `^6.1.2` | Dependency injection and ChangeNotifier state. | Adequate for current app; avoid broad rebuild scopes. |
| sqflite | `^2.4.0` | Mobile SQLite persistence. | Core DB layer for subjects, schedule, notes, and overrides. |
| sqflite_common_ffi | dev `^2.3.6` | SQLite tests on desktop VM. | Test-only dependency. |
| shared_preferences | `^2.3.2` | Simple local settings. | Used for grace windows and gallery-save preference. |
| image_picker | `^1.1.2` | Camera/image capture. | Mobile behavior must be tested on device. |
| google_mlkit_text_recognition | `^0.13.0` | On-device OCR. | Mobile-first dependency; web compile does not prove OCR runtime support. |
| permission_handler | `^11.3.1` | Camera/runtime permission flow. | Android/iOS permissions must stay aligned with manifests. |
| path_provider | `^2.1.5` | App document directories. | Used for managed images and exports. |
| path | `^1.9.1` | Path normalization and safe path checks. | Required for managed file deletion/export guards. |
| intl | `^0.20.1` | Date/time formatting. | Used in UI and PDF exports. |
| pdf | `^3.11.1` | PDF timeline generation. | Reads managed images and note text. |
| gal | `^2.3.1` | Optional gallery copy of captured photos. | Best-effort; internal app storage remains canonical. |
| flutter_localizations | Flutter SDK | Localization support. | Generated localization classes exist; hardcoded UI strings remain localization debt. |
| flutter_lints | dev `^5.0.0` | Static lint baseline. | `flutter analyze` currently passes. |

## Data Model

SQLite database: `aulens.db`, version from `AppConstants.dbVersion`.

| Table | Purpose | Important fields |
| --- | --- | --- |
| `subjects` | User-defined classes/subjects. | `id`, `name`, `professor`, `classroom`, `is_archived`. |
| `schedule` | Weekly recurring time blocks. | `subject_id`, `weekday`, `start_time`, `end_time`, `title`. |
| `notes` | Photo/text notes. | `subject_id`, `note_type`, `image_path`, `ocr_text`, `text_content`, `created_at`. |
| `session_overrides` | Per-date subject override for a detected schedule slot. | `schedule_entry_id`, `date`, `subject_id`. |

Behavior:

- Subject deletion cascades to schedule rows and notes in SQLite.
- Subject archiving preserves notes/schedule but hides subject from active views.
- Notes can be unclassified when no subject is detected.
- General timeline loading uses `getNotesMetadata()` to exclude heavy text fields.
- Search uses `searchNotesInDb()` and returns text fields only for matching rows so snippets can render.

## Provider and Service Responsibilities

| Component | Role |
| --- | --- |
| `ScheduleProvider` | Loads subjects/schedule/overrides, exposes active vs archived subjects, resolves current class, archives/restores subjects, writes session overrides. |
| `NotesProvider` | Loads metadata notes, creates/deletes/moves notes, updates OCR/details, performs async DB search, builds class sessions for timelines. |
| `SettingsProvider` | Loads and updates grace windows plus gallery-save preference. |
| `ClassModeController` | Tracks whether the class-mode prompt is open or dismissed. |
| `DatabaseService` | Owns raw SQL schema, migrations, and CRUD/query methods. |
| `ScheduleService` | Thin domain wrapper around schedule DB operations. |
| `NotesService` | Thin domain wrapper around note DB operations and managed image deletion. |
| `SettingsService` | SharedPreferences wrapper. |
| `CameraService` | Image capture/persistence, background OCR task event stream, gallery export, managed image path checks. |
| `OcrService` | ML Kit text extraction with native recognizer lifecycle. |
| `PermissionService` | Camera permission state/request flow. |
| `PdfExportService` | Generates timeline PDFs and writes them to app documents. |

## Feature Workflows

### Schedule and Class Detection

1. User creates `Subject` rows and `ScheduleEntry` rows.
2. `ScheduleProvider.getCurrentClass()` delegates to `TimeUtils.matchEntryForTimestamp()`.
3. `main.dart` periodically checks active class state.
4. If an active class exists and the prompt is not dismissed, `ClassModePage` opens.
5. Manual subject overrides are stored in `session_overrides` for a specific date and schedule slot.

### Camera and OCR

1. `CameraPage` checks permission through `PermissionService`.
2. `CameraService.capturePhoto()` invokes `image_picker` and copies the file into app-managed documents storage.
3. `NotesProvider.addPhotoNote()` creates a DB row immediately.
4. `CameraService.enqueueBackgroundOcr()` emits task events and runs OCR asynchronously.
5. `OcrService.extractText()` creates and closes a `TextRecognizer` per image.
6. `NotesProvider.updateOcrText()` updates SQLite and in-memory state.

### Notes and Timelines

1. `NotesProvider` loads metadata rows on startup.
2. Notes are grouped by subject and then into `ClassSession` buckets.
3. `ClassTimelineView` groups notes captured close together into short time windows.
4. Detail screens load the full note text by ID on demand.
5. Full-screen photo view supports paging, zoom, pan, and double-tap zoom.

### Search

1. `SearchPage` sends trimmed query text to `NotesProvider.searchNotesAsync()`.
2. Provider increments `_searchVersion` to ignore stale async results.
3. `DatabaseService.searchNotesInDb()` performs SQLite `LIKE` over OCR/manual text.
4. Search result rows include the matching text fields for snippets/highlighting.

### Export

1. `PdfExportService.generateClassTimelinePdf()` builds a document from subject notes.
2. Managed image paths are validated before file reads.
3. Missing/invalid images render placeholders instead of failing the export.
4. Files are written under an `exports` directory in app documents.

## Platform Map

| Platform | Current state |
| --- | --- |
| Android | Primary practical target. Manifest has camera/media permissions. Package ID is still `com.example.aulens`; release signing still uses debug config and must be fixed before publication. |
| iOS | Runner metadata and camera/photo usage descriptions exist. Needs physical device validation for capture/OCR. |
| Web | `flutter build web` succeeds. Treat as compile validation unless camera/OCR behavior is explicitly made web-compatible. |
| Linux desktop | Project files exist, but host is missing native build dependencies. OCR/camera behavior may differ from mobile. |
| macOS/Windows | Generated Flutter platform scaffolds exist; not currently validated. |

## Quality Gates

Current passing checks are formatting, static analysis, automated tests, and web compilation. The exact commands and environment setup live in `docs/DEVELOPMENT.md`.

Known environment blockers:

- Android SDK is missing on the host.
- Chrome executable is missing on the host.
- Linux desktop toolchain lacks clang, CMake, and GTK development libraries.

## Dependency Currency

`flutter pub outdated` on 2026-05-11 shows the project is healthy but not fully current:

- 18 dependencies are locked to older patch/minor versions in `pubspec.lock`.
- 6 dependencies are constrained behind resolvable newer versions in `pubspec.yaml`.
- Highest-risk upgrade candidates are `google_mlkit_text_recognition` `0.13.1 -> 0.15.1`, `permission_handler` `11.4.0 -> 12.0.1`, and `flutter_lints` `5.0.0 -> 6.0.0`.
- Package upgrades should be done as a separate change after Android device validation is available, because camera, permission, and OCR packages need real-device verification.

Android device validation must run on a physical device once Android SDK/platform-tools are available in the isolated development environment. See `docs/DEVELOPMENT.md` for the ADB Wi-Fi and deploy workflow.

## Roadmap

Highest-value next steps:

1. Create a Fedora Toolbox Android development environment and validate on a physical Android device.
2. Replace template Android identifiers and debug release signing before any public distribution.
3. Decide whether web/desktop are supported or compile-only targets.
4. Expand tests around providers, migrations, class-mode prompt behavior, note deletion, and managed file guards.
5. Convert hardcoded UI strings into the localization workflow.
6. Consider SQLite FTS for larger note collections.
7. Consider `go_router`, typed DB tooling, or a stronger repository boundary only when concrete complexity justifies it.
