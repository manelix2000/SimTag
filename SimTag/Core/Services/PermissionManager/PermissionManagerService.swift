import Foundation
import ScreenCaptureKit

/// Manages screen recording permission for window tracking
/// Source: https://developer.apple.com/documentation/screencapturekit/accessing_screen_content
@MainActor
class PermissionManagerService: ObservableObject {
    @Published private(set) var hasPermission: Bool = false
    @Published private(set) var permissionStatus: PermissionStatus = .notDetermined

    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
    }

    init() {
        Task {
            await checkPermission()
        }
    }

    /// Check current screen recording permission status by attempting to access content
    /// Returns true if permission is granted
    @discardableResult
    func checkPermission() async -> Bool {
        do {
            // Try to access shareable content
            // This is the most reliable way to check ScreenCaptureKit permission
            _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            // If we got here, permission is granted
            hasPermission = true
            permissionStatus = .authorized
            return true
        } catch {
            // Failed to access content - check if it's a permission issue
            let errorDescription = error.localizedDescription

            if errorDescription.contains("not authorized") ||
               errorDescription.contains("denied") ||
               errorDescription.contains("permission") {
                hasPermission = false
                permissionStatus = hasRequestedBefore() ? .denied : .notDetermined
                return false
            }

            // Other error - assume permission granted but something else failed
            // This prevents false negatives
            print("WARNING: Permission check failed with unexpected error: \(error)")
            hasPermission = false
            permissionStatus = .notDetermined
            return false
        }
    }

    /// Request screen recording permission
    /// This will show the system permission dialog
    func requestPermission() async {
        // Mark as requested
        markAsRequested()

        // The old API (CGRequestScreenCaptureAccess) is unreliable
        // Instead, we try to access content which will trigger the permission dialog
        await checkPermission()

        // If still no permission, open System Settings
        if !hasPermission {
            openSystemSettings()
        }
    }

    /// Open System Settings to Privacy & Security > Screen Recording
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private let hasRequestedKey = "com.simtag.hasRequestedScreenRecording"

    private func hasRequestedBefore() -> Bool {
        UserDefaults.standard.bool(forKey: hasRequestedKey)
    }

    private func markAsRequested() {
        UserDefaults.standard.set(true, forKey: hasRequestedKey)
    }
}
