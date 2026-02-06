import Foundation
import AppKit

/// Triggers the macOS Automation permission prompt for Safari.
/// This doesn't grant permission automatically — it just causes the system prompt to appear.
enum SafariPermissionManager {
    static func requestAutomationPermission() {
        // Minimal AppleScript call to Safari that should trigger the prompt.
        // If Safari isn't running, we still "tell" it; macOS may launch it depending on settings.
        let scriptSource = """
        tell application "Safari"
            if (count of documents) is 0 then
                return ""
            else
                return name of front document
            end if
        end tell
        """

        Task.detached(priority: .utility) {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: scriptSource) else { return }
            _ = script.executeAndReturnError(&error)
            // Intentionally ignore result; prompt is the goal.
        }
    }
}

