import Foundation
import CoreGraphics
import AppKit

/// Injects an expansion in three steps:
///   1. Send N backspaces to erase the trigger.
///   2. Write the expansion to NSPasteboard.
///   3. Send Cmd+V to paste; restore the original pasteboard after.
///
/// The `matcher` reference lets the injector set `isExpanding` so the
/// TriggerMatcher ignores keystrokes generated during injection.
public final class ExpansionInjector: @unchecked Sendable {

    public weak var matcher: TriggerMatcher?

    private let backspaceCode: CGKeyCode = 51
    private let vKeyCode:      CGKeyCode = 9

    public init() {}

    public func inject(expansion: String, triggerLength: Int) {
        matcher?.isExpanding = true
        matcher?.reset()

        // Small delay so the final trigger key-up event is delivered first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self else { return }
            self.sendBackspaces(count: triggerLength)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                guard let self else { return }
                let pb    = NSPasteboard.general
                let saved = pb.string(forType: .string)

                pb.clearContents()
                pb.setString(expansion, forType: .string)
                self.sendCmdV()

                // Restore original pasteboard after paste completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    pb.clearContents()
                    if let saved { pb.setString(saved, forType: .string) }
                    self?.matcher?.isExpanding = false
                }
            }
        }
    }

    // MARK: - Key events

    private func sendBackspaces(count: Int) {
        for _ in 0..<count {
            postKey(backspaceCode, down: true)
            postKey(backspaceCode, down: false)
        }
    }

    private func sendCmdV() {
        let src  = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }

    private func postKey(_ code: CGKeyCode, down: Bool) {
        CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)?
            .post(tap: .cgSessionEventTap)
    }
}
