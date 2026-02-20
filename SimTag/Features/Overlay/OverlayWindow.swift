import AppKit
import SwiftUI

/// Floating overlay window that appears on top of simulator windows
/// Configured to be transparent, borderless, and mouse-transparent
class OverlayWindow: NSPanel {

    // MARK: - Initialization

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configure()
    }

    // MARK: - Configuration

    private func configure() {
        // Window level - float above simulator windows
        level = .floating

        // Collection behavior - appear on all spaces and don't activate
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]

        // Transparency
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Mouse interaction - let clicks pass through to simulator
        ignoresMouseEvents = true

        // Don't show in window switcher or Exposé
        hidesOnDeactivate = false
    }

    // MARK: - Window Behavior

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}
