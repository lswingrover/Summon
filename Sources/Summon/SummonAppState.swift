import AppKit
import SummonCore

/// Central shared state for Summon. Owns the SnippetStore (created here so
/// it's available before applicationDidFinishLaunching when SwiftUI evaluates
/// App.body to build the scene graph).
@MainActor
final class SummonAppState: ObservableObject {
    static let shared = SummonAppState()

    // Store lives here so Window scenes can reference it safely at init time
    let store = SnippetStore()

    // MARK: - Published state

    @Published var isEnabled: Bool = {
        guard UserDefaults.standard.object(forKey: "summon.enabled") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "summon.enabled")
    }()

    @Published var requireWordBoundary: Bool = {
        guard UserDefaults.standard.object(forKey: "summon.wordBoundary") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "summon.wordBoundary")
    }()

    @Published var accessibilityGranted: Bool = false
    @Published var snippetCount: Int = 0

    // Set by AppDelegate after launch
    weak var monitor: KeyboardMonitor?

    // MARK: - Init

    private init() {
        refreshAccessibility()
    }

    // MARK: - Actions

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: "summon.enabled")
        if value {
            guard KeyboardMonitor.isAccessibilityGranted() else { return }
            monitor?.start()
        } else {
            monitor?.stop()
        }
    }

    func setWordBoundary(_ value: Bool) {
        requireWordBoundary = value
        UserDefaults.standard.set(value, forKey: "summon.wordBoundary")
    }

    func refreshAccessibility() {
        accessibilityGranted = KeyboardMonitor.isAccessibilityGranted()
    }

    func refreshSnippetCount() {
        Task {
            let count = await store.snippets.count
            await MainActor.run { snippetCount = count }
        }
    }

    func requestAccessibility() {
        KeyboardMonitor.requestAccessibility()
        Task {
            try? await Task.sleep(for: .seconds(1))
            refreshAccessibility()
        }
    }
}
