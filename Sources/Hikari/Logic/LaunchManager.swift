import Foundation
import ServiceManagement

@available(macOS 13.0, *)
class LaunchManager: ObservableObject {
    @Published var isLaunchAtLoginEnabled: Bool = false
    
    private let service = SMAppService.mainApp
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        isLaunchAtLoginEnabled = service.status == .enabled
    }
    
    func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled {
            do {
                try service.unregister()
                print("[LaunchManager] Unregistered successfully")
            } catch {
                print("[LaunchManager] Failed to unregister: \(error)")
            }
        } else {
            do {
                try service.register()
                print("[LaunchManager] Registered successfully")
            } catch {
                print("[LaunchManager] Failed to register: \(error)")
            }
        }
        checkStatus()
    }
}
