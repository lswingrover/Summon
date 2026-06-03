import AppKit
import SwiftUI
import SummonCore

@main
struct SummonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // appState is the single source of truth — store lives inside it,
    // so Window scene content closures can reference appState.store
    // safely at scene-graph build time (before applicationDidFinishLaunching).
    @StateObject private var appState      = SummonAppState.shared
    @StateObject private var updateChecker = UpdateChecker()

    var body: some Scene {
        // ── Menu bar ─────────────────────────────────────────────────────────
        MenuBarExtra("Summon", systemImage: "s.circle.fill") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(updateChecker)
                .onAppear {
                    appState.refreshAccessibility()
                    appState.refreshSnippetCount()
                    updateChecker.checkInBackground()
                }
        }
        .menuBarExtraStyle(.menu)

        // ── Snippet Manager ───────────────────────────────────────────────────
        Window("Snippet Manager", id: "snippets") {
            SnippetManagerView(store: appState.store)
                .environmentObject(appState)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    appState.refreshSnippetCount()
                }
                .onDisappear {
                    appState.refreshSnippetCount()
                    setAccessoryIfNoWindows()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 720, height: 520)

        // ── Preferences ───────────────────────────────────────────────────────
        Window("Preferences", id: "prefs") {
            PreferencesView()
                .environmentObject(appState)
                .environmentObject(updateChecker)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    appState.refreshAccessibility()
                }
                .onDisappear { setAccessoryIfNoWindows() }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 320)
        .keyboardShortcut(",", modifiers: .command)

        // ── About ─────────────────────────────────────────────────────────────
        Window("About Summon", id: "about") {
            AboutView()
                .environmentObject(updateChecker)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear { setAccessoryIfNoWindows() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private func setAccessoryIfNoWindows() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let open = NSApp.windows.filter { $0.isVisible }
            if open.isEmpty { NSApp.setActivationPolicy(.accessory) }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {

    let monitor  = KeyboardMonitor()
    let matcher  = TriggerMatcher()
    let injector = ExpansionInjector()

    // Store comes from SummonAppState — no separate reference needed
    private var store: SnippetStore { SummonAppState.shared.store }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Wire monitor back-ref into shared state
        SummonAppState.shared.monitor = monitor
        SummonAppState.shared.refreshSnippetCount()

        // Start companion API
        CompanionServer.shared.start(store: store)

        // Wire expansion pipeline
        setupExpansionPipeline()

        // Start or show accessibility prompt
        if KeyboardMonitor.isAccessibilityGranted() {
            if SummonAppState.shared.isEnabled { monitor.start() }
        } else {
            showAccessibilityAlert()
        }
    }

    // MARK: - Expansion pipeline

    private func setupExpansionPipeline() {
        injector.matcher = matcher

        monitor.onChar = { [weak self] char in
            guard let self else { return }
            Task {
                let active = await self.store.activeSnippets
                if let match = self.matcher.process(char: char, against: active) {
                    await MainActor.run {
                        self.injector.inject(
                            expansion: match.expansion,
                            triggerLength: match.trigger.count
                        )
                    }
                }
            }
        }

        monitor.onBackspace = { [weak self] in
            self?.matcher.handleBackspace()
        }
    }

    // MARK: - Accessibility

    private func showAccessibilityAlert() {
        KeyboardMonitor.requestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText     = "Accessibility Permission Required"
            alert.informativeText = "Summon needs Accessibility access to detect your trigger shortcuts system-wide.\n\nGo to System Settings → Privacy & Security → Accessibility and enable Summon, then relaunch."
            alert.alertStyle      = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
        }
    }
}
