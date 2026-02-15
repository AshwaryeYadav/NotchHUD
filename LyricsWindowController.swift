import AppKit
import SwiftUI

final class LyricsWindowController: NSWindowController {
    private static var sharedController: LyricsWindowController?
    
    static func show(nowPlaying: NowPlayingManager) {
        if sharedController == nil {
            sharedController = LyricsWindowController(nowPlaying: nowPlaying)
        }
        
        sharedController?.showWindow(nil)
        sharedController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    convenience init(nowPlaying: NowPlayingManager) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = NSWindow.TitleVisibility.hidden
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        panel.level = NSWindow.Level.floating
        
        // Center on screen
        panel.center()
        
        let lyricsView = LyricsView(nowPlaying: nowPlaying) {
            panel.close()
        }
        
        let hostingView = NSHostingView(rootView: lyricsView)
        panel.contentView = hostingView
        
        self.init(window: panel)
    }
}
