import Foundation
import CoreGraphics
import AppKit
import IOKit.graphics

struct DisplayMode: Identifiable, Hashable {
    let id: Int
    let width: Int
    let height: Int
    let refreshRate: Double
    let ioMode: CGDisplayMode?
    
    // Custom hash/eq to group by resolution + rate
    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(Int(refreshRate * 10)) // simple refresh bucketing
    }
    
    static func == (lhs: DisplayMode, rhs: DisplayMode) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height && abs(lhs.refreshRate - rhs.refreshRate) < 0.1
    }
}

@MainActor
class DisplayEngine: ObservableObject {
    @Published var displays: [CGDirectDisplayID] = []
    
    init() {
        refreshDisplays()
    }
    
    func refreshDisplays() {
        var count: UInt32 = 0
        var allDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        
        // Try Private CGS API which might see disabled displays
        let result = PrivateSkyLight.getDisplayList(max: 16, displays: &allDisplays, count: &count)
        
        if result != 0 || count == 0 {
             // Fallback to public online list
             guard CGGetOnlineDisplayList(16, &allDisplays, &count) == .success else { return }
        }
        
        // Include displays that are Online OR the Built-in panel
        let validDisplays = Set(allDisplays.prefix(Int(count)).filter { 
            $0 != 0 && (CGDisplayIsOnline($0) != 0 || CGDisplayIsBuiltin($0) != 0)
        })
        
        self.displays = Array(validDisplays).sorted()
        
        // Safety check: if no displays are active, and built-in exists, turn it on!
        ensureActiveDisplay()
    }
    
    func ensureActiveDisplay() {
        // Count active displays
        var activeCount = 0
        var builtinID: CGDirectDisplayID? = nil
        
        for id in displays {
            if isActive(displayID: id) {
                activeCount += 1
            }
            if CGDisplayIsBuiltin(id) != 0 {
                builtinID = id
            }
        }
        
        // If nothing is active, but we have a internal screen, rescue the user!
        if activeCount == 0, let targetID = builtinID {
            print("[Engine] Recovery: No active displays detected. Force enabling built-in display: \(targetID)")
            setPowerState(displayID: targetID, turnOn: true)
        }
    }
    
    func isActive(displayID: CGDirectDisplayID) -> Bool {
        return CGDisplayIsActive(displayID) != 0
    }
    
    // Power Control
    func setPowerState(displayID: CGDirectDisplayID, turnOn: Bool) {
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        print("[Engine] setPowerState id=\(displayID) builtin=\(isBuiltin) on=\(turnOn)")
        
        // Safety: Prevent disabling the last active display
        if !turnOn && displays.count <= 1 {
            print("[Engine] Safety: Cannot disable the last active display!")
            return
        }
        
        // Logical Enable/Disable (Software Clamshell Mode)
        // This makes windows move to other screens.
        // We wrap this in a config block.
        var config: CGDisplayConfigRef?
        let err = CGBeginDisplayConfiguration(&config)
        if err == .success, let cfg = config {
            let kCGConfigurePermanently: CGConfigureOption = .permanently
            
            // Call private API
            let result = PrivateSkyLight.setDisplayEnabled(config: cfg, displayID: displayID, enabled: turnOn)
            print("[Engine] PrivateSkyLight.setDisplayEnabled result: \(result)")
            
            if result == 0 {
                CGCompleteDisplayConfiguration(cfg, kCGConfigurePermanently)
            } else {
                CGCancelDisplayConfiguration(cfg)
            }
        }
    }
    
    func getBrightness(displayID: CGDirectDisplayID) -> Float? {
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        if isBuiltin {
            // 1. Modern M1 approach
            if let b = PrivateDisplayServices.getBrightness(displayID: displayID) {
                return b
            }
            
            // 2. Legacy IOKit approach (Intel)
            let service = DDC.findService(for: displayID)
            if service != 0 {
                defer { IOObjectRelease(service) }
                var brightness: Float = 0
                let brightnessKey = "brightness" as CFString
                IODisplayGetFloatParameter(service, 0, brightnessKey, &brightness)
                return brightness
            }
        }
        return nil
    }
    
    func setBrightness(displayID: CGDirectDisplayID, level: Float) {
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        if isBuiltin {
            // 1. Modern M1 approach
            PrivateDisplayServices.setBrightness(displayID: displayID, level: level)
            
            // 2. Legacy IOKit approach (Intel)
            let service = DDC.findService(for: displayID)
            if service != 0 {
                defer { IOObjectRelease(service) }
                let brightnessKey = "brightness" as CFString
                IODisplaySetFloatParameter(service, 0, brightnessKey, level)
            }
        }
    }
    
    func getModes(for displayID: CGDirectDisplayID) -> [DisplayMode] {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
            return []
        }
        
        var availableModes: [DisplayMode] = []
        
        for mode in modes {
            let width = mode.width
            let height = mode.height
            let rate = mode.refreshRate
            // CGDisplayModeGetRefreshRate returns 0 for some panels, fallback to 60 if 0?
            // Some connection types don't report rate.
            
            let safeRate = rate > 0 ? rate : 60.0
            
            // To ensure we can actually switch to it, keep reference to CGDisplayMode
            let dm = DisplayMode(id: Int(mode.ioDisplayModeID), width: width, height: height, refreshRate: safeRate, ioMode: mode)
            
            availableModes.append(dm)
        }
        
        // Deduplicate: CoreGraphics returns many modes that look identical (different flags/pixel formats)
        // We want unique Resolution + Refresh Rate combinations.
        // We picking the "best" ioMode for each combination is tricky, usually the defaults are fine.
        
        // Group by custom existing hashable
        let unique = Set(availableModes)
        return Array(unique).sorted { 
            if $0.width != $1.width { return $0.width > $1.width }
            if $0.height != $1.height { return $0.height > $1.height }
            return $0.refreshRate > $1.refreshRate
        }
    }
    
    func setMode(displayID: CGDirectDisplayID, mode: DisplayMode) {
        guard let ioMode = mode.ioMode else { return }
        
        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        CGConfigureDisplayWithDisplayMode(config, displayID, ioMode, nil)
        CGCompleteDisplayConfiguration(config, .permanently)
    }
    
    func getCurrentMode(for displayID: CGDirectDisplayID) -> DisplayMode? {
        guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        let width = mode.width
        let height = mode.height
        let rate = mode.refreshRate
        let safeRate = rate > 0 ? rate : 60.0
        
        return DisplayMode(id: Int(mode.ioDisplayModeID), width: width, height: height, refreshRate: safeRate, ioMode: mode)
    }
    
    func getName(for displayID: CGDirectDisplayID) -> String {
        // Fallback name
        if CGDisplayIsBuiltin(displayID) != 0 {
            return "Built-in Display"
        }
        
        // Getting actual name requires IOKit iteration similar to DDC, or using screen localizedName
        // Map CGDirectDisplayID to NSScreen?
        if let screen = NSScreen.screens.first(where: { 
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID 
        }) {
            return screen.localizedName
        }
        
        return "External Display (\(displayID))"
    }
}
