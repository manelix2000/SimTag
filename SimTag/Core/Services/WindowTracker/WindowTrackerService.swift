import Foundation

/// Protocol for tracking simulator windows
/// Single Responsibility: Detect and track iOS Simulator windows
protocol WindowTrackerService: AnyObject {
    /// Callback invoked when the list of tracked windows changes
    var onWindowsChanged: (([SimulatorWindow]) -> Void)? { get set }

    /// Start tracking simulator windows
    func startTracking() async throws

    /// Stop tracking simulator windows
    func stopTracking()

    /// Get the current list of tracked windows
    func getCurrentWindows() -> [SimulatorWindow]
}
