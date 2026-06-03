# Summon

**Free, local-first text expander for macOS.**

Type a short trigger — Summon replaces it with the full expansion instantly, in any app.

```
;addr  →  123 Main Street, Post Falls, ID 83854
;sig   →  Best,\nLouis Swingrover
;meet  →  Let's find a time: calendly.com/...
```

---

## Features

- **System-wide expansion** — works in every app: browsers, editors, email, Slack, Terminal
- **Menu bar app + full snippet manager** — quick access from the menu bar, full window for managing your library
- **Free forever** — no subscription, no cloud account required
- **Local-first** — all snippets stored locally in SQLite (`~/Library/Application Support/Summon/summon.db`)
- **Companion plugin** — manage snippets conversationally via Claude (Cowork mode)

---

## Install

### Requirements
- macOS 14 (Sonoma) or later
- Xcode Command Line Tools: `xcode-select --install`

### Build & Install

```bash
git clone https://github.com/lswingrover/summon.git
cd summon
bash build_app.sh
```

This builds and installs `Summon.app` to `/Applications`.

### Grant Accessibility Permission

Summon uses macOS Accessibility to detect your trigger shortcuts system-wide.

1. Launch Summon from `/Applications`
2. Click **"Open System Settings"** in the prompt that appears
3. In System Settings → Privacy & Security → Accessibility, toggle **Summon** on
4. Relaunch Summon

> This permission is required for system-wide expansion. Summon only reads keystrokes to detect triggers — it never logs or transmits your typing.

---

## Usage

### Add a snippet
1. Click the **S** icon in your menu bar
2. Click **+** (Add Snippet)
3. Enter a **trigger** (e.g. `;addr`) and **expansion** (the full text)
4. Click **Add Snippet**

### Use a snippet
Type the trigger anywhere — in any app — followed by a space, punctuation, or newline. Summon replaces it instantly.

### Tips
- Prefix triggers with `;` or `!` to avoid accidental matches (e.g. `;email` not `email`)
- Use the **Label** field to describe what a snippet is for
- Disable individual snippets with the toggle in the editor — they stay in your library but won't expand

---

## Companion Plugin (Claude / Cowork)

Summon includes a companion Cowork plugin so you can manage snippets via conversation.

### Install the companion plugin
1. Install the companion plugin via Claude → Settings → Capabilities → Plugins → Upload
2. The plugin file is at `companion-plugin/summon-companion.plugin`

### Available skills
- **summon-list** — list all your snippets
- **summon-add** — add a snippet by describing it
- **summon-search** — find snippets by keyword

### Example
> "Add a snippet: trigger `;meet`, expansion 'Would love to find a time — grab a slot: https://cal.com/me'"

---

## Architecture

```
Sources/
├── SummonCore/          # Pure Swift — no AppKit, fully testable
│   ├── Snippet.swift       Model
│   ├── DatabaseManager.swift   SQLite CRUD
│   ├── SnippetStore.swift      Actor wrapping DatabaseManager
│   ├── TriggerMatcher.swift    Rolling-buffer trigger detection
│   ├── KeyboardMonitor.swift   CGEventTap (system-wide keyboard intercept)
│   └── ExpansionInjector.swift Backspace + pasteboard paste
└── Summon/              # AppKit/SwiftUI app
    ├── SummonApp.swift      Entry point + AppDelegate
    ├── SnippetManagerView.swift  Full-window snippet list
    ├── SnippetEditorView.swift   Add/edit sheet
    ├── CompanionServer.swift     HTTP API on port 14732
    └── AboutView.swift
Tests/
└── SummonTests/
    ├── DatabaseManagerTests.swift
    └── TriggerMatcherTests.swift
```

**Expansion pipeline:** `KeyboardMonitor` → `TriggerMatcher` → `ExpansionInjector` → paste

The `SummonCore` library contains all business logic with no AppKit dependency, making it fully unit-testable.

---

## Running Tests

```bash
swift test
```

---

## Privacy

- Summon **never** logs, stores, or transmits your keystrokes
- All snippets are stored locally; no network requests are made except the companion API on `localhost:14732`
- Accessibility permission is used solely to intercept trigger characters and inject expansions

---

## Suite

Summon is part of a suite of local-first macOS utilities:

| App | Description |
|-----|-------------|
| [ClipWatch](https://github.com/lswingrover/ClipWatch) | Clipboard history manager |
| [MacWatch](https://github.com/lswingrover/MacWatch) | System health monitor |
| [NetWatch](https://github.com/lswingrover/NetWatch) | Home network monitor |
| [GridForge](https://github.com/lswingrover/gridforge) | Window layout manager |
| **Summon** | Text expander |

---

## License

MIT
