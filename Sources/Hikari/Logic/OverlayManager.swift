import Cocoa
import SwiftUI

class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        
        self.isOpaque = false
        self.backgroundColor = NSColor.black
        self.alphaValue = 0.0 // Start transparent
        self.level = .floating // Above normal windows
        self.ignoresMouseEvents = true // Click-through
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Ensure it covers full screen including menu bar area if possible
        // (contentRect is usually safe frame, needs frame)
        self.setFrame(screen.frame, display: true)
    }
}

class OverlayManager: ObservableObject {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    
    // 0.0 = Normal (No dimming), 1.0 = Black
    @Published var dimmingLevels: [CGDirectDisplayID: Double] = [:]
    
    @MainActor
    func updateOverlays() {
        let activeScreens = NSScreen.screens
        let currentIDs = Set(activeScreens.compactMap { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID })
        
        // 1. Hide/Remove windows for displays that are no longer in NSScreen.screens
        for (id, window) in windows {
            if !currentIDs.contains(id) {
                window.orderOut(nil)
            }
        }
        
        // 2. Sync windows with active screens
        for screen in activeScreens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            
            if windows[id] == nil {
                let win = OverlayWindow(screen: screen)
                windows[id] = win
            }
            
            let win = windows[id]!
            
            // Ensure window is on top and visible
            win.setFrame(screen.frame, display: true)
            win.orderFront(nil)
            
            // Calculate effective alpha
            refreshAlpha(for: id)
        }
    }
    
    @MainActor
    func setBrightness(displayID: CGDirectDisplayID, brightness: Double) {
        // Map brightness 1.0 -> 0.0 alpha, 0.0 -> 0.95 alpha
        let maxOverlay: Double = 0.95
        let inverted = (1.0 - brightness) * maxOverlay
        dimmingLevels[displayID] = inverted
        
        refreshAlpha(for: displayID)
    }
    
    @MainActor
    private func refreshAlpha(for id: CGDirectDisplayID) {
        let dimAlpha = dimmingLevels[id] ?? 0.0
        windows[id]?.alphaValue = CGFloat(dimAlpha)
    }
}
