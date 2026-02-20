import Foundation

/// Information about a running simulator
struct SimulatorInfo: Codable, Equatable {
    let udid: String
    let name: String
    let state: String
    let deviceTypeIdentifier: String?
    let runtimeIdentifier: String?

    /// Extract iOS version from runtime identifier
    /// e.g., "com.apple.CoreSimulator.SimRuntime.iOS-17-0" -> "17.0"
    var iOSVersion: String? {
        guard let runtime = runtimeIdentifier else { return nil }

        // Runtime format: com.apple.CoreSimulator.SimRuntime.iOS-XX-X
        let components = runtime.components(separatedBy: ".")
        guard let lastComponent = components.last else { return nil }

        // Extract version from "iOS-17-0"
        let versionParts = lastComponent.components(separatedBy: "-")
        guard versionParts.count >= 3, versionParts[0] == "iOS" else { return nil }

        return versionParts[1...].joined(separator: ".")
    }

    /// Check if simulator is currently running
    var isBooted: Bool {
        state.lowercased() == "booted"
    }
}

/// Protocol for extracting simulator information
/// Single Responsibility: Provide metadata about running simulators
protocol SimulatorInfoService {
    /// Get list of all booted simulators
    func getBootedSimulators() async throws -> [SimulatorInfo]

    /// Extract device info from window title
    /// Window titles follow format: "Device Name – iOS Version" or just "Device Name"
    /// Returns tuple with device name and optional iOS version
    func extractDeviceInfo(from windowTitle: String) -> (name: String, osVersion: String?)
}
