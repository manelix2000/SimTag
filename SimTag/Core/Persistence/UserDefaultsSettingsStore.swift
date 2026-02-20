import Foundation

/// UserDefaults-based implementation of SettingsStore
class UserDefaultsSettingsStore: SettingsStore {

    // MARK: - Keys

    private enum Keys {
        static let launchAtLogin = "com.simtag.settings.launchAtLogin"
        static let defaultPosition = "com.simtag.settings.defaultPosition"
        static let overlayConfigurations = "com.simtag.settings.overlayConfigurations"
    }

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Global Settings

    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    var defaultOverlayPosition: OverlayConfiguration.Position {
        get {
            guard let rawValue = defaults.string(forKey: Keys.defaultPosition),
                  let position = OverlayConfiguration.Position(rawValue: rawValue) else {
                return .bottomCenter // Default value
            }
            return position
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.defaultPosition)
        }
    }

    // MARK: - Per-Simulator Settings

    func getOverlayConfiguration(for simulatorKey: String) -> OverlayConfiguration? {
        let allConfigs = getAllConfigurations()
        return allConfigs[simulatorKey]
    }

    func saveOverlayConfiguration(_ config: OverlayConfiguration, for simulatorKey: String) {
        var allConfigs = getAllConfigurations()
        allConfigs[simulatorKey] = config

        // Encode and save
        if let encoded = try? JSONEncoder().encode(allConfigs) {
            defaults.set(encoded, forKey: Keys.overlayConfigurations)
        }
    }

    func removeOverlayConfiguration(for simulatorKey: String) {
        var allConfigs = getAllConfigurations()
        allConfigs.removeValue(forKey: simulatorKey)

        // Encode and save
        if let encoded = try? JSONEncoder().encode(allConfigs) {
            defaults.set(encoded, forKey: Keys.overlayConfigurations)
        }
    }

    func getAllConfigurations() -> [String: OverlayConfiguration] {
        guard let data = defaults.data(forKey: Keys.overlayConfigurations),
              let configs = try? JSONDecoder().decode([String: OverlayConfiguration].self, from: data) else {
            return [:]
        }
        return configs
    }
}
