# Aulens Agent Guide

This file is the canonical development guide for AI agents and developers working on Aulens. Keep it current whenever architecture, workflows, tooling, or preservation rules change.

## Project Overview

Aulens is a Flutter student note-taking app that organizes class notes around a weekly schedule.

The core workflow is:

1. Users create subjects and weekly schedule entries.
2. The app detects the active class from local device time plus configured grace windows.
3. Users capture whiteboard photos or create text notes.
4. Captured photos are persisted in managed app storage.
5. On-device OCR runs asynchronously and updates the saved note when complete.
6. Notes appear in subject timelines and can be searched by OCR/manual text.

The app is local-first and single-user. Do not add backend, cloud sync, account, or multi-user assumptions unless the user explicitly expands the scope.

## Current Architecture

- Flutter app with feature-based folders under `lib/features/`.
- Shared infrastructure under `lib/shared/` and cross-cutting utilities under `lib/core/`.
- Top-level dependency wiring is in `lib/main.dart` using `provider` and `ChangeNotifier`.
- Local persistence is SQLite through `sqflite`, centered in `DatabaseService`.
- Settings are stored through `shared_preferences`.
- Camera and image selection use `image_picker`.
- OCR uses `google_mlkit_text_recognition` on-device; no Firebase/backend is required.
- PDF export uses the `pdf` package.
- Runtime permissions use `permission_handler`.
- Current app screens cover schedule, notes, camera, search, settings, class mode, archived subjects, note detail, photo viewer, and subject timelines.
- See `docs/ARCHITECTURE.md` for the full architecture map, technology inventory, quality assessment, and development roadmap.
- See `docs/DEVELOPMENT.md` for the practical Fedora Toolbox setup, Android Wi-Fi testing, and build/deploy workflow.

## Data Model and Persistence

Primary SQLite tables:

- `subjects`: class subjects, including professor/classroom metadata and archive state.
- `schedule`: recurring weekly class blocks linked to subjects.
- `notes`: photo or text notes; photo notes may have `image_path`, `ocr_text`, and optional `text_content`.
- `session_overrides`: per-date overrides when a captured note should belong to a different subject than the detected class.

Preserve `ON DELETE CASCADE` behavior for subject-related schedule rows and notes. Deleting a subject is destructive; archiving should preserve notes and schedule data.

## Hard Preservation Rules

- Preserve existing app flows and user data behavior.
- Do not rewrite the architecture wholesale; work incrementally.
- Keep OCR non-blocking and failure-tolerant.
- Save photo notes immediately, then update OCR text asynchronously.
- Keep photos in managed app storage; only delete files after confirming the path is inside the managed images directory.
- Keep schedule/class detection based on local device time and configured grace windows.
- Keep notes lists lightweight by loading metadata only.
- Load full note text only in detail/search contexts that require it.
- Keep the app usable without network access after dependencies are installed.

## Performance Rules

- Never decode full-resolution whiteboard images in list or timeline thumbnails.
- Use `cacheWidth` for `Image.file` thumbnails.
- Do not load `ocr_text` or `text_content` into general notes/timeline list screens unless required.
- Search must stay database-backed; do not load all notes into Dart memory for full-text filtering.
- Prefer `ListView.builder`, `GridView.builder`, and lazy builders for repeated UI.
- Avoid broad `context.watch` calls around full `Scaffold` trees when only a small subtree needs provider updates.
- When implementing search-as-you-type, keep the version-token pattern (`_searchVersion`) so stale async query results are ignored.
- Use Material 3 color roles through `Theme.of(context).colorScheme`.
- New user-visible strings should go through the app localization layer or be tracked as localization debt if the current generated files are not expanded in that change.

## AI Agent Operating Rules

This file is the single AI-development source of truth for the repository.

- All AI agents must read this `AGENTS.md` before planning or editing.
- Do not use `GEMINI.md`, `CLAUDE.md`, `.cursorrules`, or IDE-only prompts as competing project guidance.
- If another tool requires its own instruction file, make that file a short pointer to `AGENTS.md`; do not duplicate rules.
- When using Codex, ChatGPT, Gemini, Claude, Cursor, Continue, Aider, or another agent, paste or reference this file first and tell the agent to treat it as authoritative.
- Keep architectural rationale in tracked Markdown files, not only in chat.
- Before editing, inspect existing code paths and preserve behavior unless the user explicitly asks for a redesign.
- After editing, run the smallest useful validation set and report any environment blocker directly.
- Never hide mock behavior, unsupported platforms, missing SDKs, or partial validation.

## Fedora Development Environment

Default strategy: use Fedora Toolbox backed by rootless Podman for interactive development. `docs/DEVELOPMENT.md` is the source of truth for exact setup, validation, ADB Wi-Fi, build, and deploy commands.

Rationale:

- Podman is native to Fedora, rootless, SELinux-aware, and available on the host.
- Toolbox provides an ergonomic mutable development shell without installing Flutter/Android/Linux desktop dependencies directly on the host.
- Docker is not the default here because the Docker client exists but the daemon/socket is unavailable in the observed environment.
- Raw Podman containers can be added later for CI-style reproducible validation once the interactive workflow is stable.

Recommended host policy:

- Keep the host limited to Podman, Toolbox, editor integration, and source checkout.
- Install Android SDK, Java, Chrome/Chromium, GTK/Linux desktop build dependencies, and Flutter caches inside Toolbox or a project-scoped mounted directory.
- Do not install heavyweight mobile build dependencies directly on Fedora unless the user explicitly chooses that tradeoff.

Alternatives:

- Toolbox: recommended default for this repository. It is interactive, Fedora-native, Podman-backed, and has practical access to home, networking, `/dev`, and host integration.
- Distrobox: a good alternative if you already use it or need more image choices. It solves a similar problem but adds another tool to manage.
- Raw Podman container: best later for CI-like reproducible checks, but less ergonomic for interactive Android development and ADB.
- Dev Containers: good for team-wide IDE reproducibility, but still needs careful ADB/network setup for physical Android devices.
- Host install: simplest and most officially documented, but intentionally avoided here because it installs SDKs/caches/toolchains directly on Fedora.

Operational rule: do not copy environment setup commands into this file. Update `docs/DEVELOPMENT.md` when setup, build, deploy, or device-testing steps change.

## Current Verified State

The verified quality state and known environment blockers are tracked in `docs/ARCHITECTURE.md`. Exact validation commands belong in `docs/DEVELOPMENT.md`.

Agent rule: never claim Android, iOS, camera, permission, or OCR runtime validation unless it was run on a physical mobile device in the current change set.

## Near-Term Development Plan

Priority 1: repository and documentation hygiene.

- Keep this `AGENTS.md` as the canonical AI/developer guide.
- Keep `README.md` aligned with the actual app, not the Flutter template.
- Keep generated build outputs out of version control.
- Keep `.gitignore` tracked and do not ignore it from itself.

Priority 2: low-risk correctness fixes.

- Keep the SQLite database version source of truth aligned.
- Remove dead service/provider wiring when functionality has moved elsewhere.
- Support intentional clearing of nullable note fields.
- Keep search results useful by returning enough text for snippets/highlights while preserving metadata-only timeline loading.

Priority 3: baseline test coverage and expansion.

- Keep tests for class time matching and grace windows.
- Keep tests for nullable note updates.
- Keep tests for database-backed search behavior.
- Expand coverage when touching provider state, migrations, class mode, capture flow, or note deletion.

Priority 4: environment reproducibility.

- Keep the documented Toolbox workflow verified as Fedora, Flutter, and Android SDK versions move.
- Add raw Podman or devcontainer automation later if repeated validation needs it.

Priority 5: production readiness.

- Replace template Android application IDs/signing defaults before publication.
- Decide whether web/desktop are supported platforms or compile-only targets, because OCR/camera dependencies are mobile-first.
- Consider SQLite FTS if note search grows beyond simple `LIKE` queries.
- Consider a typed database layer or repository boundary only when schema/test complexity justifies it.

## Implementation Standards

- Prefer existing patterns over new abstractions.
- Keep edits scoped to the requested behavior.
- Use `dart format` after code edits.
- Run `flutter analyze` after functional changes.
- Add tests for behavior that can regress silently.
- When a platform-specific build cannot run because tooling is missing, state the blocker clearly instead of implying success.
