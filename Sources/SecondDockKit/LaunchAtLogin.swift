import Foundation
import ServiceManagement

/// Launch at login (pribadi, tanpa sandbox).
public enum LaunchAtLogin {
    public static var enabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("SecondDock autostart gagal: \(error)")
        }
    }
}
