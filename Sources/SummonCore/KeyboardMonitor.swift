import Foundation
import CoreGraphics
import AppKit

/// Installs a CGEventTap to intercept keyboard events system-wide.
///
/// Requires Accessibility permission (System Settings > Privacy & Security > Accessibility).
/// Check `KeyboardMonitor.isAccessibilityGranted()` before calling `start()`.
public final class KeyboardMonitor: @unchecked Sendable {

    /// Called with each printable character typed.
    public var onChar: ((Character) -> Void)?
    /// Called when backspace (keyCode 51) is pressed.
    public var onBackspace: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) public var isRunning = false

    public init() {}

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning, Self.isAccessibilityGranted() else { return }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    public func stop() {
        guard isRunning, let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        self.tap = nil
        runLoopSource = nil
        isRunning = false
    }

    // MARK: - Event handling

    private func handleEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Backspace
        if keyCode == 51 {
            onBackspace?()
            return
        }

        // Convert to character via NSEvent
        guard
            let nsEvent = NSEvent(cgEvent: event),
            let chars   = nsEvent.characters,
            let char    = chars.first,
            !char.isControl
        else { return }

        onChar?(char)
    }

    // MARK: - Permission helpers

    public static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility permission.
    public static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
