# Contributing to Summon

Summon is a macOS text expander — a native Swift app with a companion HTTP API on port 14732 and a Claude Cowork plugin. It uses `CGEventTap` for system-wide keyboard interception and SQLite for snippet storage. This document covers how to build, test, and extend it.

---

## Before you write code

1. **Read the README.** The CGEventTap model, the trigger-detection algorithm, and the companion API contract are all documented there.
2. **Check the roadmap.**
3. **Build and run first.** Port 14732 must be free; check before starting.

---

## Environment

- macOS 14+ (Sonoma)
- Xcode 15+ / Swift 5.9+
- No external package manager dependencies
- Build target: `My Mac` (not simulator)
- Signing: **ad-hoc only**. Never reconfigure for App Store or notarization.
- **Accessibility permission required** at runtime (`CGEventTap` requires it). The README covers how to grant it.
- The companion HTTP API runs on **localhost:14732** — this port is fixed.

---

## Building

Open `summon.xcodeproj` in Xcode and press ⌘B. For releases, `build_app.sh` handles ad-hoc signing and bundle assembly (used by the `scotty:summon-ship` skill).

---

## Architecture principles

**CGEventTap is the keyboard layer.** All keystroke interception happens here. This is the most sensitive part of the app: a bug here can make the keyboard non-functional or introduce input lag. Test any CGEventTap change extensively before committing.

**Latency is the enemy.** Expansion must be instantaneous from the user's perspective. The trigger-detection loop must not block on I/O. SQLite reads for snippet lookup must be on a fast path — cache hot snippets in memory.

**The companion API is the interface.** Claude skills add, update, and search snippets through the HTTP API on port 14732. The API surface must remain stable.

**SQLite for persistence.** All snippets and metadata persist in SQLite. FTS5 for text search. Do not use UserDefaults for snippet data.

**Menu bar first.** Summon lives in the menu bar.

---

## Code standards

- **Swift 5.9+** with structured concurrency.
- **SwiftUI** for UI. AppKit only where unavoidable.
- **No force unwraps** in new code.
- **No hardcoded paths** — use `FileManager` APIs.
- **No personal data in source.** Snippets are user data and are stored in SQLite, not in source.
- **Port 14732 is a constant** — define once, reference everywhere.

---

## CGEventTap safety rules

- Never block the event tap callback for more than 1ms.
- Never call back into AppKit/SwiftUI from the event tap callback thread.
- Always release taps cleanly on app exit — a leaked tap can persist across app death.
- Test with Accessibility permission both granted and denied; the app must degrade gracefully.

---

## Companion API contract

The API (localhost:14732) serves the summon-companion plugin. Any endpoint you add or change:

1. Update the route documentation in `docs/api.md`
2. Update the relevant SKILL.md in `companion/summon-companion.plugin/`
3. Rebuild the companion plugin with `scotty:summon-companion-ship`

---

## Branch and commit conventions

Branches: `main` (stable), `feature/X`, `fix/X`, `refactor/X`

Commit format (Conventional Commits):

    feat(api): add PATCH /snippets/:id endpoint
    fix(eventtap): prevent double-expansion on fast typists
    refactor(db): cache snippet hot set in memory

---

## Testing

1. Build succeeds with zero warnings.
2. Run Summon and verify the companion API responds: `curl http://localhost:14732/status`
3. Grant Accessibility permission and verify a trigger expands correctly.
4. Verify snippets survive an app restart (SQLite roundtrip).
5. Test with Accessibility permission denied — app must degrade gracefully.
6. Test the companion plugin if you changed any API endpoint.

---

## Companion plugin

The Claude Cowork plugin lives in `companion/summon-companion.plugin/`. Run `scotty:summon-companion-ship` to rebuild after any SKILL.md change.

---

## Related

- [MacWatch](https://github.com/lswingrover/MacWatch) — system health monitor
- [NetWatch](https://github.com/lswingrover/NetWatch) — network health monitor
- [ClipWatch](https://github.com/lswingrover/ClipWatch) — clipboard monitor
- [GridForge](https://github.com/lswingrover/GridForge) — window layout manager (companion API on port 14731)
- [obrien](https://github.com/lswingrover/obrien) — Cowork companion plugin framework
