import Foundation
import CoreGraphics

/// Represents a tracked iOS Simulator window
struct SimulatorWindow: Identifiable, Hashable, Codable {
    let id: UUID
    let windowID: CGWindowID
    let bundleIdentifier: String
    let deviceUDID: String
    let deviceName: String
    var frame: CGRect
    var isVisible: Bool
    var isFocused: Bool  // Whether this window is currently focused/active

    // Phase 5: Git repository detection
    var runningAppBundleID: String?           // Bundle ID of iOS app running inside simulator
    var associatedRepository: GitRepository?   // Detected git repo

    init(
        id: UUID = UUID(),
        windowID: CGWindowID,
        bundleIdentifier: String,
        deviceUDID: String,
        deviceName: String,
        frame: CGRect,
        isVisible: Bool = true,
        isFocused: Bool = false,
        runningAppBundleID: String? = nil,
        associatedRepository: GitRepository? = nil
    ) {
        self.id = id
        self.windowID = windowID
        self.bundleIdentifier = bundleIdentifier
        self.deviceUDID = deviceUDID
        self.deviceName = deviceName
        self.frame = frame
        self.isVisible = isVisible
        self.isFocused = isFocused
        self.runningAppBundleID = runningAppBundleID
        self.associatedRepository = associatedRepository
    }

    /// Generate composite key for identifying simulators uniquely
    var compositeKey: String {
        "\(bundleIdentifier)_\(deviceUDID)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(deviceUDID)
    }

    static func == (lhs: SimulatorWindow, rhs: SimulatorWindow) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.deviceUDID == rhs.deviceUDID
    }
}
