import AppKit
import SwiftUI
import SummonCore

@main
struct SummonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    var statusItem: NSStatusItem?
    var snippetWindow: NSWindow?
    var aboutWindow:   NSWindow?

    let store    = SnippetStore()
    let monitor  = KeyboardMonitor()
    let matcher  = TriggerMatcher()
    let injector = ExpansionInjector()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupExpansionPipeline()
        checkAccessibility()
        CompanionServer.shared.start(store: store)
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "s.circle.fill", accessibilityDescription: "Summon")
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(statusBarClicked)
        button.target = self
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleSnippetManager()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Snippet Manager", action: #selector(openSnippetManager), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About Summon", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Summon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func toggleSnippetManager() {
        if let w = snippetWindow, w.isVisible { w.close() } else { openSnippetManager() }
    }

    @objc func openSnippetManager() {
        if snippetWindow == nil {
            let hosting = NSHostingView(rootView: SnippetManagerView(store: store))
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false
            )
            w.title = "Summon — Snippet Manager"
            w.contentView = hosting
            w.center()
            w.setFrameAutosaveName("SummonManager")
            snippetWindow = w
        }
        snippetWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            w.title = "About Summon"
            w.contentView = NSHostingView(rootView: AboutView())
            w.center()
            aboutWindow = w
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
                        self.injector.inject(expansion: match.expansion, triggerLength: match.trigger.count)
                    }
                }
            }
        }

        monitor.onBackspace = { [weak self] in
            self?.matcher.handleBackspace()
        }

        monitor.start()
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        guard !KeyboardMonitor.isAccessibilityGranted() else { return }
        KeyboardMonitor.requestAccessibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Summon needs Accessibility access to detect your trigger shortcuts and expand them system-wide.\n\nGo to System Settings > Privacy & Security > Accessibility and enable Summon, then relaunch."
            alert.alertStyle = .warning
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
