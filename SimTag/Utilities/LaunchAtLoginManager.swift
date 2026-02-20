import Foundation
import ServiceManagement

/// Manages Launch at Login functionality using SMAppService
/// Source: https://developer.apple.com/documentation/servicemanagement/smappservice
@MainActor
class LaunchAtLoginManager {

    // MARK: - Singleton

    static let shared = LaunchAtLoginManager()

    private init() {}

    // MARK: - Public Properties

    /// Current status of launch at login
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Public Methods

    /// Enable launch at login
    /// - Throws: LaunchAtLoginError if registration fails
    func enable() throws {
        guard SMAppService.mainApp.status != .enabled else {
            print("INFO LaunchAtLogin: Already enabled")
            return
        }

        do {
            try SMAppService.mainApp.register()
            print("INFO LaunchAtLogin: Successfully enabled")
        } catch {
            print("ERROR LaunchAtLogin: Failed to enable - \(error)")
            throw LaunchAtLoginError.registrationFailed(error)
        }
    }

    /// Disable launch at login
    /// - Throws: LaunchAtLoginError if unregistration fails
    func disable() throws {
        guard SMAppService.mainApp.status == .enabled else {
            print("INFO LaunchAtLogin: Already disabled")
            return
        }

        do {
            try SMAppService.mainApp.unregister()
            print("INFO LaunchAtLogin: Successfully disabled")
        } catch {
            print("ERROR LaunchAtLogin: Failed to disable - \(error)")
            throw LaunchAtLoginError.unregistrationFailed(error)
        }
    }

    /// Set launch at login status
    /// - Parameter enabled: Whether to enable or disable
    /// - Throws: LaunchAtLoginError if operation fails
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    /// Get detailed status information
    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not Registered"
        case .notFound:
            return "Not Found"
        case .requiresApproval:
            return "Requires Approval (check System Settings)"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Error Types

enum LaunchAtLoginError: LocalizedError {
    case registrationFailed(Error)
    case unregistrationFailed(Error)
    case requiresApproval

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let error):
            return "Failed to enable Launch at Login: \(error.localizedDescription)"
        case .unregistrationFailed(let error):
            return "Failed to disable Launch at Login: \(error.localizedDescription)"
        case .requiresApproval:
            return "Launch at Login requires approval in System Settings → General → Login Items"
        }
    }
}
