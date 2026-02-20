import Foundation
import SwiftUI

/// ViewModel for the Settings window
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var launchAtLogin: Bool {
        didSet {
            settingsStore.launchAtLogin = launchAtLogin

            // Update system launch at login setting
            Task { @MainActor in
                do {
                    try LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
                } catch {
                    print("ERROR: Failed to update launch at login: \(error)")
                    // Revert the UI state if registration failed
                    self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
                }
            }
        }
    }

    @Published var selectedPosition: OverlayConfiguration.Position {
        didSet {
            // Save position for current simulator if one is selected
            if let simulator = selectedSimulator {
                var config = settingsStore.getOverlayConfiguration(for: simulator.compositeKey)
                    ?? OverlayConfiguration(simulatorKey: simulator.compositeKey, position: selectedPosition)
                config.position = selectedPosition
                settingsStore.saveOverlayConfiguration(config, for: simulator.compositeKey)

                // Notify that settings changed
                onSettingsChanged?()
            }
        }
    }

    @Published var activeSimulators: [SimulatorWindow] = []
    @Published var selectedSimulator: SimulatorWindow? {
        didSet {
            updateSelectedPosition()
        }
    }

    // MARK: - Dependencies

    private var settingsStore: SettingsStore  // Changed to var to allow mutation
    var onSettingsChanged: (() -> Void)?
    var onQuit: (() -> Void)?

    // MARK: - Initialization

    init(settingsStore: SettingsStore = UserDefaultsSettingsStore()) {
        self.settingsStore = settingsStore
        // Sync with actual system state on launch
        self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
        self.selectedPosition = settingsStore.defaultOverlayPosition
    }

    // MARK: - Public Methods

    func updateActiveSimulators(_ simulators: [SimulatorWindow]) {
        activeSimulators = simulators

        // Auto-select first simulator if none selected
        if selectedSimulator == nil, let first = simulators.first {
            selectedSimulator = first
        } else if let selected = selectedSimulator {
            // Update selected simulator if it still exists
            selectedSimulator = simulators.first(where: { $0.id == selected.id })
        }
    }

    func selectSimulator(_ simulator: SimulatorWindow) {
        selectedSimulator = simulator
    }

    func getPosition(for simulator: SimulatorWindow) -> OverlayConfiguration.Position {
        return settingsStore.getOverlayConfiguration(for: simulator.compositeKey)?.position
            ?? settingsStore.defaultOverlayPosition
    }

    func quit() {
        onQuit?()
    }

    // MARK: - Private Methods

    private func updateSelectedPosition() {
        guard let simulator = selectedSimulator else { return }
        selectedPosition = getPosition(for: simulator)
    }
}
