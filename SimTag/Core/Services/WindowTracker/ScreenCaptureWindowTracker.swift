import Foundation
import ScreenCaptureKit
import AppKit

/// ScreenCaptureKit implementation for window tracking
/// Source: https://developer.apple.com/documentation/screencapturekit
@MainActor
class ScreenCaptureWindowTracker: WindowTrackerService {
    // MARK: - WindowTrackerService Protocol

    var onWindowsChanged: (([SimulatorWindow]) -> Void)?

    // MARK: - Private Properties

    private var currentWindows: [SimulatorWindow] = []
    private var pollingTimer: Timer?
    private var isTracking = false
    private let simulatorInfoService: SimulatorInfoService

    /// Polling interval in seconds
    private let pollingInterval: TimeInterval = 1.0

    // MARK: - Initialization

    init(simulatorInfoService: SimulatorInfoService = SimctlInfoProvider()) {
        self.simulatorInfoService = simulatorInfoService
    }

    // MARK: - Public Methods

    func startTracking() async throws {
        guard !isTracking else { return }

        isTracking = true

        // Initial window detection
        try await updateWindows()

        // Start periodic polling for window position/size updates
        startPolling()
    }

    func stopTracking() {
        isTracking = false
        stopPolling()
        currentWindows.removeAll()
    }

    func getCurrentWindows() -> [SimulatorWindow] {
        return currentWindows
    }

    // MARK: - Private Methods

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.updateWindows()
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func updateWindows() async throws {
        // Get all shareable content (windows) with retry logic
        let content = try await RetryHelper.retry(maxAttempts: 2, initialDelay: 0.2) {
            try await SCShareableContent.excludingDesktopWindows(
                false, // Include desktop windows is fine
                onScreenWindowsOnly: true // Only windows currently visible
            )
        }

        // Filter for Simulator app windows
        let simulatorWindows = content.windows.filter { window in
            guard let app = window.owningApplication else { return false }
            return app.bundleIdentifier == "com.apple.iphonesimulator"
        }

        // Get booted simulators from simctl with error handling
        let bootedSimulators: [SimulatorInfo]
        do {
            bootedSimulators = try await simulatorInfoService.getBootedSimulators()
        } catch {
            Logger.warning("Failed to get booted simulators: \(error.localizedDescription)")
            bootedSimulators = []
        }

        // Convert to SimulatorWindow models with actual simulator info
        let newWindows = simulatorWindows.compactMap { scWindow -> SimulatorWindow? in
            createSimulatorWindow(from: scWindow, bootedSimulators: bootedSimulators)
        }

        // Check if windows changed
        if !windowsAreEqual(currentWindows, newWindows) {
            currentWindows = newWindows
            onWindowsChanged?(currentWindows)
        }
    }

    private func createSimulatorWindow(
        from scWindow: SCWindow,
        bootedSimulators: [SimulatorInfo]
    ) -> SimulatorWindow? {
        // Extract window frame and title
        // IMPORTANT: SCWindow.frame uses screen coordinates with origin at TOP-LEFT
        // (Y=0 at top of screen, Y increases downward)
        let frame = scWindow.frame
        let windowTitle = scWindow.title ?? "iOS Simulator"

        // Parse device info from window title
        let (deviceName, osVersion) = simulatorInfoService.extractDeviceInfo(from: windowTitle)

        // Try to match with a booted simulator by device name
        let matchedSimulator = findMatchingSimulator(
            deviceName: deviceName,
            osVersion: osVersion,
            in: bootedSimulators
        )

        // Use matched simulator info if available, otherwise fallback values
        let deviceUDID = matchedSimulator?.udid ?? "unknown-\(scWindow.windowID)"

        // For bundle ID, we use the simulator app's bundle for now
        // In a future phase, we could detect the running app inside the simulator
        let bundleID = "com.apple.iphonesimulator"

        // Check if this window is currently focused
        let isFocused = isWindowFocused(scWindow)

        return SimulatorWindow(
            windowID: scWindow.windowID,
            bundleIdentifier: bundleID,
            deviceUDID: deviceUDID,
            deviceName: deviceName,
            frame: frame,
            isVisible: true,
            isFocused: isFocused
        )
    }

    /// Check if a window is currently focused (frontmost)
    private func isWindowFocused(_ scWindow: SCWindow) -> Bool {
        // Get the frontmost app
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // Check if it's the Simulator app
        guard frontmostApp.bundleIdentifier == "com.apple.iphonesimulator" else {
            return false
        }

        // Get all windows from the frontmost app
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // Find the frontmost simulator window
        // Look for the window with the highest window layer that belongs to the simulator
        for windowInfo in windowList {
            if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
               let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
               ownerPID == frontmostApp.processIdentifier,
               windowID == scWindow.windowID {
                // Check if this is the main/key window (layer 0)
                let layer = windowInfo[kCGWindowLayer as String] as? Int ?? -1
                return layer == 0
            }
        }

        return false
    }

    /// Match a window to a simulator based on device name and OS version
    private func findMatchingSimulator(
        deviceName: String,
        osVersion: String?,
        in simulators: [SimulatorInfo]
    ) -> SimulatorInfo? {
        // First, try exact match with both name and OS version
        if let osVersion = osVersion {
            if let match = simulators.first(where: { simulator in
                simulator.name == deviceName && simulator.iOSVersion == osVersion
            }) {
                return match
            }
        }

        // Fallback: match by device name only
        // This handles cases where window title doesn't include OS version
        return simulators.first(where: { $0.name == deviceName })
    }

    /// Compare two arrays of SimulatorWindow for equality
    /// Checks window ID, frame, visibility, and focus state
    private func windowsAreEqual(_ lhs: [SimulatorWindow], _ rhs: [SimulatorWindow]) -> Bool {
        guard lhs.count == rhs.count else { return false }

        let lhsSorted = lhs.sorted { $0.windowID < $1.windowID }
        let rhsSorted = rhs.sorted { $0.windowID < $1.windowID }

        for (left, right) in zip(lhsSorted, rhsSorted) {
            if left.windowID != right.windowID ||
               !left.frame.equalTo(right.frame) ||
               left.isVisible != right.isVisible ||
               left.isFocused != right.isFocused {
                return false
            }
        }

        return true
    }
}
