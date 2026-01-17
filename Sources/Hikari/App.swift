import SwiftUI
import AppKit

// MARK: - Menu Bar View
struct MenuContent: View {
    @ObservedObject var displayEngine: DisplayEngine
    @ObservedObject var overlayManager: OverlayManager
    @ObservedObject var launchManager: LaunchManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.yellow)
                Text("Hikari")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Quit App")
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(displayEngine.displays, id: \.self) { displayID in
                    DisplayControlCard(
                        id: displayID,
                        name: displayEngine.getName(for: displayID),
                        engine: displayEngine,
                        overlay: overlayManager
                    )
                }
            }
            .padding(12)
            
            Divider()
                .padding(.horizontal)
            
            // Footer with Launch at Login
            HStack {
                Text("Launch at Login")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { launchManager.isLaunchAtLoginEnabled },
                    set: { _ in launchManager.toggleLaunchAtLogin() }
                ))
                .toggleStyle(.switch)
                .tint(.green)
                .scaleEffect(0.6)
                .frame(width: 30)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow).ignoresSafeArea())
    }
}

struct DisplayControlCard: View {
    let id: CGDirectDisplayID
    let name: String
    @ObservedObject var engine: DisplayEngine
    @ObservedObject var overlay: OverlayManager
    
    @State private var brightness: Double = 1.0
    @State private var isPowerOn: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title & Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                    if !engine.isActive(displayID: id) {
                        Text("Disabled")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isPowerOn)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .scaleEffect(0.7)
                    .frame(width: 40)
                    .onChange(of: isPowerOn) { isOn in
                        engine.setPowerState(displayID: id, turnOn: isOn)
                    }
            }
            
            if isPowerOn {
                // Brightness
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "sun.min.fill")
                            .font(.system(size: 10))
                        Slider(value: $brightness, in: 0.0...1.0)
                            .controlSize(.small)
                            .onChange(of: brightness) { newVal in
                                if CGDisplayIsBuiltin(id) != 0 {
                                    engine.setBrightness(displayID: id, level: Float(newVal))
                                } else {
                                    overlay.setBrightness(displayID: id, brightness: newVal)
                                }
                            }
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10))
                    }
                }
                
                // Resolution
                HStack {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(engine.getModes(for: id), id: \.self) { mode in
                            Button("\(mode.width) x \(mode.height) @ \(Int(mode.refreshRate))Hz") {
                                engine.setMode(displayID: id, mode: mode)
                                engine.refreshDisplays()
                            }
                        }
                    } label: {
                        Text(currentModeString())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .opacity(1.0)
        .onAppear {
            isPowerOn = engine.isActive(displayID: id)
            if let b = engine.getBrightness(displayID: id) {
                brightness = Double(b)
            }
        }
        .onChange(of: engine.displays) { _ in
            isPowerOn = engine.isActive(displayID: id)
            if let b = engine.getBrightness(displayID: id) {
                brightness = Double(b)
            }
        }
    }
    
    private func currentModeString() -> String {
        if let mode = engine.getCurrentMode(for: id) {
            return "\(mode.width)×\(mode.height) @ \(Int(mode.refreshRate))Hz"
        }
        return "Select Resolution"
    }
}

// Visual Effect Blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    var displayEngine: DisplayEngine!
    var overlayManager: OverlayManager!
    var launchManager: LaunchManager!
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Engines
        displayEngine = DisplayEngine()
        overlayManager = OverlayManager()
        launchManager = LaunchManager()
        
        // Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Use "光" symbol as Icon
            if let iconImage = imageFromText("光", size: NSSize(width: 18, height: 18)) {
                iconImage.isTemplate = true // Ensures it adapts to light/dark mode
                button.image = iconImage
            } else {
                button.image = NSImage(systemSymbolName: "sun.max.circle.fill", accessibilityDescription: "Hikari")
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create Popover
        let contentView = MenuContent(
            displayEngine: displayEngine, 
            overlayManager: overlayManager,
            launchManager: launchManager
        )
        
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Initial Overlay Update
        overlayManager.updateOverlays()
        
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.displayEngine.refreshDisplays()
                self?.overlayManager.updateOverlays()
            }
        }
    }
    
    // Helper to create an image from text
    private func imageFromText(_ text: String, size: NSSize) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        
        let stringSize = text.size(withAttributes: attributes)
        let rect = NSRect(x: (size.width - stringSize.width) / 2,
                          y: (size.height - stringSize.height) / 2,
                          width: stringSize.width,
                          height: stringSize.height)
        
        text.draw(in: rect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
    
    @MainActor
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                overlayManager.updateOverlays() 
                launchManager.checkStatus()
            }
        }
    }
}

@main
struct DisplayManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
