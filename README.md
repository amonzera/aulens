# Aulens

Aulens is a local-first Flutter app for student note-taking. It organizes whiteboard photos and manual text notes by subject using a weekly class schedule, then runs on-device OCR so notes can be searched later.

## Core Workflow

1. Create subjects and schedule entries.
2. Let Aulens detect the current class from local time and grace windows.
3. Capture whiteboard photos or add text notes.
4. Store photos locally in app-managed storage.
5. Run OCR asynchronously and update the saved note when extraction finishes.
6. Browse notes in class timelines or search OCR/manual text.

## Development

Recommended environment on Fedora: use Toolbox backed by rootless Podman so Flutter, Android SDK, Chrome, and native build dependencies do not pollute the host system.

Project docs:

- `AGENTS.md`: AI/developer rules and preservation constraints.
- `docs/ARCHITECTURE.md`: architecture map, technologies, workflows, and roadmap.
- `docs/DEVELOPMENT.md`: step-by-step setup, validation, Android Wi-Fi testing, and deploy workflow.
