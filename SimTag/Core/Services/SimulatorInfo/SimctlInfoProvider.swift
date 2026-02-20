import Foundation

/// simctl implementation for simulator information extraction
/// Source: https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/
class SimctlInfoProvider: SimulatorInfoService {

    // MARK: - SimulatorInfoService Protocol

    func getBootedSimulators() async throws -> [SimulatorInfo] {
        let output = try await executeSimctl()
        let simulators = try parseSimctlOutput(output)

        // Filter only booted simulators
        return simulators.filter { $0.isBooted }
    }

    func extractDeviceInfo(from windowTitle: String) -> (name: String, osVersion: String?) {
        // Window title formats:
        // "iPhone 15 Pro – 17.0"
        // "iPad Pro (12.9-inch) – 16.0"
        // "iPhone 14" (without OS version)

        // Split by em dash or regular dash
        let separator = windowTitle.contains("–") ? "–" : "-"
        let components = windowTitle.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }

        if components.count >= 2 {
            let deviceName = components[0]
            let osVersion = components[1]
            return (deviceName, osVersion)
        } else {
            // No separator found, entire title is device name
            return (windowTitle, nil)
        }
    }

    // MARK: - Private Methods

    /// Execute simctl command to get device list
    private func executeSimctl() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "list", "devices", "-j"]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    if let output = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: SimctlError.invalidOutput)
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: SimctlError.executionFailed(errorMessage))
                }
            } catch {
                continuation.resume(throwing: SimctlError.processError(error))
            }
        }
    }

    /// Parse simctl JSON output
    /// JSON structure:
    /// {
    ///   "devices": {
    ///     "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
    ///       {
    ///         "udid": "...",
    ///         "name": "iPhone 15 Pro",
    ///         "state": "Booted",
    ///         "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
    ///       }
    ///     ]
    ///   }
    /// }
    private func parseSimctlOutput(_ output: String) throws -> [SimulatorInfo] {
        guard let data = output.data(using: .utf8) else {
            throw SimctlError.invalidOutput
        }

        let decoder = JSONDecoder()

        do {
            let response = try decoder.decode(SimctlResponse.self, from: data)

            var allSimulators: [SimulatorInfo] = []

            for (runtimeIdentifier, devices) in response.devices {
                for device in devices {
                    var simulatorInfo = SimulatorInfo(
                        udid: device.udid,
                        name: device.name,
                        state: device.state,
                        deviceTypeIdentifier: device.deviceTypeIdentifier,
                        runtimeIdentifier: runtimeIdentifier
                    )
                    allSimulators.append(simulatorInfo)
                }
            }

            return allSimulators
        } catch {
            print("ERROR: Failed to parse simctl output: \(error)")
            throw SimctlError.parsingFailed(error)
        }
    }

    // MARK: - Error Types

    enum SimctlError: Error, LocalizedError {
        case executionFailed(String)
        case processError(Error)
        case invalidOutput
        case parsingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .executionFailed(let message):
                return "simctl execution failed: \(message)"
            case .processError(let error):
                return "Process error: \(error.localizedDescription)"
            case .invalidOutput:
                return "Invalid simctl output"
            case .parsingFailed(let error):
                return "Failed to parse simctl JSON: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - JSON Decoding Structures

    private struct SimctlResponse: Codable {
        let devices: [String: [SimctlDevice]]
    }

    private struct SimctlDevice: Codable {
        let udid: String
        let name: String
        let state: String
        let deviceTypeIdentifier: String?
    }
}
