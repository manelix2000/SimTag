import SwiftUI

/// Configuration for overlay appearance and behavior
struct OverlayConfiguration: Codable, Equatable {
    enum Position: String, Codable, CaseIterable {
        case topLeft
        case topCenter
        case topRight
        case bottomLeft
        case bottomCenter
        case bottomRight

        var displayName: String {
            switch self {
            case .topLeft: return "Top Left"
            case .topCenter: return "Top Center"
            case .topRight: return "Top Right"
            case .bottomLeft: return "Bottom Left"
            case .bottomCenter: return "Bottom Center"
            case .bottomRight: return "Bottom Right"
            }
        }
    }

    let simulatorKey: String
    var position: Position
    var customLabel: String?
    var showBranchName: Bool
    var opacity: Double
    var fontSize: CGFloat

    init(
        simulatorKey: String,
        position: Position = .bottomCenter,
        customLabel: String? = nil,
        showBranchName: Bool = true,
        opacity: Double = 0.8,
        fontSize: CGFloat = 14
    ) {
        self.simulatorKey = simulatorKey
        self.position = position
        self.customLabel = customLabel
        self.showBranchName = showBranchName
        self.opacity = opacity
        self.fontSize = fontSize
    }

    /// Validate configuration values are within acceptable ranges
    func validated() -> OverlayConfiguration {
        var config = self
        config.opacity = max(0.0, min(1.0, opacity))
        config.fontSize = max(8.0, min(32.0, fontSize))
        return config
    }
}
