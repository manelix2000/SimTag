import Foundation

/// Protocol for storing and retrieving app settings
protocol SettingsStore {
    // MARK: - Global Settings

    /// Launch at login preference
    var launchAtLogin: Bool { get set }

    /// Default overlay position for new simulators
    var defaultOverlayPosition: OverlayConfiguration.Position { get set }

    // MARK: - Per-Simulator Settings

    /// Get overlay configuration for a specific simulator
    /// - Parameter simulatorKey: Composite key (bundleID + UDID)
    /// - Returns: Configuration if exists, nil otherwise
    func getOverlayConfiguration(for simulatorKey: String) -> OverlayConfiguration?

    /// Save overlay configuration for a specific simulator
    /// - Parameters:
    ///   - config: The configuration to save
    ///   - simulatorKey: Composite key (bundleID + UDID)
    func saveOverlayConfiguration(_ config: OverlayConfiguration, for simulatorKey: String)

    /// Remove configuration for a specific simulator
    /// - Parameter simulatorKey: Composite key (bundleID + UDID)
    func removeOverlayConfiguration(for simulatorKey: String)

    /// Get all saved overlay configurations
    /// - Returns: Dictionary of simulator key -> configuration
    func getAllConfigurations() -> [String: OverlayConfiguration]
}
