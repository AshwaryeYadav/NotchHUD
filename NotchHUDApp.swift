import SwiftUI
import AppKit

@main
struct NotchHUDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hud: NotchHUDWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the HUD
        hud = NotchHUDWindowController()
        hud?.setHUDEnabled(isHUDEnabled)
        
        // Create menu bar icon
        setupMenuBarIcon()
        
        // Hide dock icon (make it a pure menu bar app)
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note.house.fill", accessibilityDescription: "NotchHUD")
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "NotchHUD", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Enable HUD", action: #selector(toggleHUD(_:)), keyEquivalent: "s")
        toggleItem.target = self
        toggleItem.state = isHUDEnabled ? .on : .off
        menu.addItem(toggleItem)

        let safariPerms = NSMenuItem(title: "Enable Safari Permission…", action: #selector(requestSafariPermissions), keyEquivalent: "")
        safariPerms.target = self
        menu.addItem(safariPerms)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleHUD(_ sender: NSMenuItem) {
        isHUDEnabled.toggle()
        sender.state = isHUDEnabled ? .on : .off
        hud?.setHUDEnabled(isHUDEnabled)
    }
    
    private var isHUDEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isHUDEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isHUDEnabled") }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func requestSafariPermissions() {
        SafariPermissionManager.requestAutomationPermission()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.2, blue: 0.8),
                            Color(red: 0.2, green: 0.4, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("NotchHUD")
                .font(.system(size: 24, weight: .bold))
            
            Text("Your music, right at the notch")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.vertical)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "hand.tap.fill", text: "Hover to expand")
                FeatureRow(icon: "cursorarrow.click.2", text: "Click-through when collapsed")
                FeatureRow(icon: "music.note", text: "Works with Spotify & Apple Music")
                FeatureRow(icon: "eye.slash.fill", text: "Auto-hides when idle")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
            )
            
            Spacer()
            
            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 320, height: 400)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            
            Text(text)
                .font(.system(size: 13))
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
