import AppKit
import SwiftUI
import Combine

final class NotchHUDWindowController: NSWindowController {

    // Configuration
    private let collapsedSize = NSSize(width: 170, height: 28)
    private let expandedSize = NSSize(width: 400, height: 200)
    private let idleTimeout: TimeInterval = 5.0
    private let fadeOutDuration: TimeInterval = 0.4
    private let fadeInDuration: TimeInterval = 0.25
    
    // Position offsets (adjust these to fine-tune)
    private let rightOffset: CGFloat = 0
    private let downOffset: CGFloat = 75
    
    // State
    private var isExpanded = false
    private var isVisible = true
    private var hideTimer: Timer?
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?

    convenience init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false

        // Float above everything
        panel.level = .statusBar + 1

        // Show on all Spaces
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Don't steal focus
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        
        // Click-through when not hovered
        panel.ignoresMouseEvents = true

        // Embed SwiftUI
        let rootView = NotchHUDView()
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        panel.contentView = hostingView
        
        // Size for expanded state
        panel.setFrame(NSRect(origin: .zero, size: NSSize(width: 400, height: 200)), display: false)

        self.init(window: panel)
        
        positionAtNotch()
        setupMouseTracking()
        
        // Start with a fade-in
        window?.alphaValue = 0
        fadeIn()
        
        // Start idle timer
        resetHideTimer()
    }
    
    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Positioning at Notch
    
    func positionAtNotch() {
        guard let window = window else { return }
        
        // Find the screen with the notch (built-in display)
        let screen = NSScreen.screens.first { screen in
            if #available(macOS 12.0, *) {
                return screen.safeAreaInsets.top > 0
            }
            return false
        } ?? NSScreen.main ?? NSScreen.screens.first
        
        guard let screen else { return }
        
        let screenFrame = screen.frame
        let windowSize = window.frame.size
        
        // Center horizontally on screen (with right offset)
        let x = screenFrame.midX - windowSize.width / 2 + rightOffset
        
        // Position at the very top of the screen (with down offset)
        let menuBarHeight: CGFloat = 24
        let y = screenFrame.maxY - menuBarHeight - windowSize.height / 2 - downOffset
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - Mouse Tracking
    
    private func setupMouseTracking() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.checkMousePosition()
            return event
        }
        
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.checkMousePosition()
        }
    }
    
    private func checkMousePosition() {
        guard let window = window else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        
        if isExpanded {
            // When expanded, use the full window frame with padding
            let hoverFrame = windowFrame.insetBy(dx: -15, dy: -10)
            if !hoverFrame.contains(mouseLocation) {
                mouseExited()
            }
        } else {
            // When collapsed, only trigger on the small pill at the top-center
            let pillWidth: CGFloat = 250
            let pillHeight: CGFloat = 34
            
            let pillX = windowFrame.midX - pillWidth / 2
            let pillY = windowFrame.maxY - pillHeight
            
            // Tight hover area - only the actual pill
            let pillFrame = NSRect(
                x: pillX,
                y: pillY,
                width: pillWidth,
                height: pillHeight
            )
            
            if pillFrame.contains(mouseLocation) {
                mouseEntered()
            }
        }
    }
    
    private func mouseEntered() {
        isExpanded = true
        window?.ignoresMouseEvents = false
        hideTimer?.invalidate()
        fadeIn()
    }
    
    private func mouseExited() {
        isExpanded = false
        window?.ignoresMouseEvents = true
        resetHideTimer()
    }
    
    // MARK: - Fade Animations
    
    private func fadeIn() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
        
        isVisible = true
    }
    
    private func fadeOut() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.95
        }
        
        isVisible = false
    }
    
    private func resetHideTimer() {
        hideTimer?.invalidate()
        
        hideTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.isExpanded {
                self.fadeOut()
            }
        }
    }
}
