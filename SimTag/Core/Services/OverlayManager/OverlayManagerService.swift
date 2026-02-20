import Foundation
import AppKit
import SwiftUI

/// Manages overlay windows for simulator windows
/// Coordinates overlay lifecycle, positioning, and content updates
@MainActor
class OverlayManagerService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var activeOverlays: [String: OverlayWindow] = [:]

    // MARK: - Private Properties

    private var overlayContentData: [String: OverlayData] = [:]
    private let settingsStore: SettingsStore  // Phase 7

    // MARK: - Initialization

    init(settingsStore: SettingsStore = UserDefaultsSettingsStore()) {
        self.settingsStore = settingsStore
    }

    // MARK: - Data Structure

    private struct OverlayData {
        var branchName: String?
        var commitHash: String?
        var timestamp: String?
        var customLabel: String?
        var configuration: OverlayConfiguration
    }

    // MARK: - Public Methods

    /// Sync overlays with current simulator windows
    func syncOverlays(with simulators: [SimulatorWindow]) {
        print("DEBUG OverlayManager: syncOverlays called with \(simulators.count) windows")
        let currentKeys = Set(simulators.map { $0.compositeKey })
        let activeKeys = Set(activeOverlays.keys)

        // Remove overlays for closed simulators
        for key in activeKeys where !currentKeys.contains(key) {
            print("DEBUG OverlayManager: Removing overlay for \(key)")
            removeOverlay(for: key)
        }

        // Create or update overlays for active simulators
        for simulator in simulators {
            let key = simulator.compositeKey

            // Get or create overlay data
            if overlayContentData[key] == nil {
                print("DEBUG OverlayManager: Creating new overlay data for \(key)")

                // Phase 7: Load saved configuration or use defaults
                let savedConfig = settingsStore.getOverlayConfiguration(for: key)
                let config = savedConfig ?? OverlayConfiguration(
                    simulatorKey: key,
                    position: settingsStore.defaultOverlayPosition
                )

                overlayContentData[key] = OverlayData(
                    branchName: nil,
                    commitHash: nil,    // Phase 6
                    timestamp: nil,     // Phase 6
                    customLabel: config.customLabel,
                    configuration: config
                )
            } else {
                // Phase 7: Update configuration from settings store (in case it changed)
                if let savedConfig = settingsStore.getOverlayConfiguration(for: key) {
                    overlayContentData[key]?.configuration = savedConfig
                }
            }

            // Phase 5: Always update branch name (repository may have been detected after initial creation)
            let branchName = getBranchName(for: simulator)
            overlayContentData[key]?.branchName = branchName
            print("DEBUG OverlayManager: Branch name for \(key): \(branchName ?? "nil")")

            // Update or create overlay
            updateOverlay(for: simulator)
        }
    }

    /// Update custom label for a specific simulator
    func updateCustomLabel(_ label: String?, for simulatorKey: String) {
        guard var data = overlayContentData[simulatorKey] else { return }
        data.customLabel = label
        overlayContentData[simulatorKey] = data

        // Refresh overlay if it exists
        if let _ = activeOverlays[simulatorKey] {
            // Will be refreshed on next sync
        }
    }

    /// Update overlay position for a specific simulator
    func updatePosition(_ position: OverlayConfiguration.Position, for simulatorKey: String) {
        guard var data = overlayContentData[simulatorKey] else { return }
        data.configuration.position = position
        overlayContentData[simulatorKey] = data

        // Refresh overlay if it exists
        if let _ = activeOverlays[simulatorKey] {
            // Will be refreshed on next sync
        }
    }

    // MARK: - Private Methods

    private func updateOverlay(for simulator: SimulatorWindow) {
        let key = simulator.compositeKey
        guard let data = overlayContentData[key] else { return }

        // Get or create overlay window (reuse to avoid flicker)
        let overlayWindow: OverlayWindow
        if let existing = activeOverlays[key] {
            overlayWindow = existing
        } else {
            overlayWindow = OverlayWindow()
            activeOverlays[key] = overlayWindow
        }

        // Create content view
        let contentView = OverlayContentView(
            branchName: data.branchName,
            commitHash: data.commitHash,
            timestamp: data.timestamp,
            customLabel: data.customLabel,
            configuration: data.configuration
        )

        // Set content
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        overlayWindow.contentView = hostingView

        // Calculate overlay position (already accounts for screen boundaries)
        let overlayFrame = calculateOverlayFrame(
            for: simulator.frame,
            position: data.configuration.position,
            contentView: hostingView
        )

        // Set the frame directly - overlay follows simulator precisely
        overlayWindow.setFrame(overlayFrame, display: true, animate: false)

        // Show/hide based on focus
        if simulator.isFocused {
            overlayWindow.orderFrontRegardless()
            overlayWindow.alphaValue = 1.0
        } else {
            overlayWindow.orderOut(nil)
            overlayWindow.alphaValue = 0.0
        }
    }

    private func removeOverlay(for key: String) {
        if let overlay = activeOverlays[key] {
            overlay.close()
            activeOverlays.removeValue(forKey: key)
        }
        // Also clean up content data
        overlayContentData.removeValue(forKey: key)
    }

    /// Calculate overlay frame based on simulator frame and position
    /// Positions overlay OUTSIDE simulator, following it precisely
    private func calculateOverlayFrame(
        for simulatorFrame: CGRect,
        position: OverlayConfiguration.Position,
        contentView: NSView
    ) -> CGRect {
        // Get the intrinsic size of the content
        contentView.invalidateIntrinsicContentSize()
        let contentSize = contentView.fittingSize

        let offset: CGFloat = 4  // Small gap between simulator and overlay

        // CRITICAL: ScreenCaptureKit returns frames with TOP-LEFT origin (Y=0 at top, Y increases downward)
        // NSWindow expects BOTTOM-LEFT origin (Y=0 at bottom, Y increases upward)
        // We must convert coordinates between these two systems
        guard let screen = NSScreen.main else {
            return .zero
        }

        let screenHeight = screen.frame.height

        var x: CGFloat
        var screencaptureY: CGFloat

        // Calculate position in ScreenCaptureKit coordinate system (top-left origin)
        switch position {
        case .topLeft:
            x = simulatorFrame.minX
            screencaptureY = simulatorFrame.minY - contentSize.height - offset

        case .topCenter:
            x = simulatorFrame.midX - (contentSize.width / 2)
            screencaptureY = simulatorFrame.minY - contentSize.height - offset

        case .topRight:
            x = simulatorFrame.maxX - contentSize.width
            screencaptureY = simulatorFrame.minY - contentSize.height - offset

        case .bottomLeft:
            x = simulatorFrame.minX
            screencaptureY = simulatorFrame.maxY + offset

        case .bottomCenter:
            x = simulatorFrame.midX - (contentSize.width / 2)
            screencaptureY = simulatorFrame.maxY + offset

        case .bottomRight:
            x = simulatorFrame.maxX - contentSize.width
            screencaptureY = simulatorFrame.maxY + offset
        }

        // Convert to NSWindow coordinate system (bottom-left origin)
        // Formula: NSWindowY = screenHeight - screencaptureY - contentHeight
        let nswindowY = screenHeight - screencaptureY - contentSize.height

        return CGRect(
            x: x,
            y: nswindowY,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    /// Get branch name to display for a simulator
    /// Phase 5: Uses actual branch from associated repository
    private func getBranchName(for simulator: SimulatorWindow) -> String? {
        guard let repository = simulator.associatedRepository, repository.isValid else {
            // No repository or invalid repository
            if simulator.runningAppBundleID != nil {
                return "Unknown"  // App running but not in git
            } else {
                return "No App"  // No app running
            }
        }

        // Return branch name or "detached HEAD" indicator
        return repository.currentBranch ?? "detached"
    }
}
