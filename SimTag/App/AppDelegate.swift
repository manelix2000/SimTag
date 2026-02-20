import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var permissionManager: PermissionManagerService!
    private var windowTracker: ScreenCaptureWindowTracker!
    private var overlayManager: OverlayManagerService!
    private var repositoryDetector: RepositoryDetectorService!   // Phase 5
    private var repositoryCoordinator: RepositoryCoordinator!    // Phase 5
    private var gitMonitor: GitMonitorService!                   // Phase 6
    private var settingsStore: SettingsStore!                    // Phase 7
    private var settingsViewModel: SettingsViewModel!            // Phase 7
    private var permissionWindow: NSWindow?
    private var settingsWindow: NSWindow?                        // Phase 7
    private var detectedWindows: [SimulatorWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize services
        permissionManager = PermissionManagerService()
        windowTracker = ScreenCaptureWindowTracker()
        settingsStore = UserDefaultsSettingsStore()                    // Phase 7 - Initialize first
        overlayManager = OverlayManagerService(settingsStore: settingsStore) // Phase 7 - Pass to overlay manager
        repositoryDetector = DerivedDataRepositoryDetector()           // Phase 5
        repositoryCoordinator = RepositoryCoordinator(                 // Phase 5
            repositoryDetector: repositoryDetector
        )
        gitMonitor = FSEventsGitMonitor()                              // Phase 6
        settingsViewModel = SettingsViewModel(settingsStore: settingsStore) // Phase 7

        // Phase 7: Setup settings callbacks
        settingsViewModel.onSettingsChanged = { [weak self] in
            Task { @MainActor [weak self] in
                // Refresh overlays when settings change
                guard let self = self else { return }
                self.overlayManager.syncOverlays(with: self.detectedWindows)
                print("DEBUG: Refreshed overlays after settings change")
            }
        }

        settingsViewModel.onQuit = { [weak self] in
            self?.quit()
        }

        // Phase 6: Setup git monitor callback to update overlays when branch changes
        gitMonitor.onBranchChanged = { [weak self] changedRepo, newBranch in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("DEBUG GitMonitor: Branch changed in \(changedRepo.path.lastPathComponent) to: \(newBranch ?? "nil")")

                // Update only windows associated with this specific repository
                var updatedWindows = self.detectedWindows
                for index in updatedWindows.indices {
                    if let repo = updatedWindows[index].associatedRepository,
                       repo.path == changedRepo.path {
                        var updatedRepo = repo
                        updatedRepo.currentBranch = newBranch
                        updatedWindows[index].associatedRepository = updatedRepo
                        print("DEBUG: Updated window \(updatedWindows[index].id) with new branch: \(newBranch ?? "nil")")
                    }
                }

                self.detectedWindows = updatedWindows
                self.overlayManager.syncOverlays(with: updatedWindows)
                print("DEBUG: Updated overlays after branch change")
            }
        }
        // Setup menu bar
        setupMenuBar()

        // Setup window tracker callback
        windowTracker.onWindowsChanged = { [weak self] windows in
            Task { @MainActor in
                self?.detectedWindows = windows
                print("DEBUG: Detected \(windows.count) simulator windows")
                for window in windows {
                    print("  - Window ID: \(window.windowID), Title: \(window.deviceName)")
                }

                // Phase 7: Update settings view model with active simulators
                self?.settingsViewModel.updateActiveSimulators(windows)

                // Sync overlays immediately (even without repository info)
                self?.overlayManager.syncOverlays(with: windows)
                print("DEBUG: Synced overlays for \(windows.count) windows")

                // Phase 5: Detect repositories for all windows asynchronously
                // This updates overlays as repository info becomes available
                var mutableWindows = windows
                await self?.repositoryCoordinator.handleWindowsChanged(&mutableWindows)

                // Update detectedWindows with repository info
                self?.detectedWindows = mutableWindows

                // Phase 6: Start git monitoring for newly detected repositories
                for window in mutableWindows {
                    if let repo = window.associatedRepository,
                       !(self?.gitMonitor.isMonitoring(repository: repo) ?? false) {
                        do {
                            try self?.gitMonitor.startMonitoring(repository: repo)
                            print("DEBUG: Started git monitoring for \(repo.path.lastPathComponent)")
                        } catch {
                            print("WARNING: Failed to start git monitoring for \(repo.path.path): \(error)")
                        }
                    }
                }

                // Update overlays again with repository info
                self?.overlayManager.syncOverlays(with: mutableWindows)
                print("DEBUG: Updated overlays with repository info")

                // Phase 7: Update settings view model again after repository detection
                self?.settingsViewModel.updateActiveSimulators(mutableWindows)
            }
        }

        // Check permissions on launch
        Task { @MainActor in
            if !(await permissionManager.checkPermission()) {
                showPermissionWindow()
            } else {
                // Start tracking if we have permission
                try? await startWindowTracking()
            }
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol for tag icon
            button.image = NSImage(
                systemSymbolName: "tag.fill",
                accessibilityDescription: "SimTag"
            )
        }

        // Create menu
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(
                title: "About SimTag",
                action: #selector(showAbout),
                keyEquivalent: ""
            )
        )

        menu.addItem(NSMenuItem.separator())

        menu.addItem(
            NSMenuItem(
                title: "Request Permission",
                action: #selector(requestPermission),
                keyEquivalent: ""
            )
        )

        menu.addItem(
            NSMenuItem(
                title: "Settings...",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )

        menu.addItem(
            NSMenuItem(
                title: "Debug: Show Detected Windows",
                action: #selector(showDetectedWindows),
                keyEquivalent: "d"
            )
        )

        menu.addItem(NSMenuItem.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit SimTag",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

        statusItem.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func requestPermission() {
        showPermissionWindow()
    }

    @objc private func openSettings() {
        // Phase 7: Show settings window
        showSettingsWindow()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func showDetectedWindows() {
        let alert = NSAlert()
        alert.messageText = "Detected Simulator Windows"

        if detectedWindows.isEmpty {
            alert.informativeText = "No simulator windows detected.\n\nMake sure:\n1. iOS Simulator is running\n2. Screen Recording permission is granted"
        } else {
            var info = "Found \(detectedWindows.count) simulator window(s):\n\n"
            for window in detectedWindows {
                info += "• \(window.deviceName)\n"
                info += "  Window ID: \(window.windowID)\n"
                info += "  Device UDID: \(window.deviceUDID)\n"
                info += "  Bundle ID: \(window.bundleIdentifier)\n"
                info += "  Composite Key: \(window.compositeKey)\n"
                info += "  Frame: \(window.frame)\n\n"
            }
            alert.informativeText = info
        }

        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Window Tracking

    @MainActor
    private func startWindowTracking() async throws {
        guard permissionManager.hasPermission else {
            print("WARNING: Cannot start window tracking without screen recording permission")
            return
        }

        try await windowTracker.startTracking()
        print("INFO: Window tracking started")
    }

    // MARK: - Permission Window

    private func showPermissionWindow() {
        // Close existing window if any
        permissionWindow?.close()

        let contentView = PermissionRequestView(
            permissionManager: permissionManager,
            onClose: { [weak self] in
                self?.permissionWindow?.close()
                self?.permissionWindow = nil
            },
            onPermissionGranted: { [weak self] in
                Task { @MainActor [weak self] in
                    try? await self?.startWindowTracking()
                }
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "SimTag - Permission Required"
        window.contentView = hostingView

        // Size window to fit content
        hostingView.invalidateIntrinsicContentSize()
        window.setContentSize(hostingView.fittingSize)

        window.center()
        window.setFrameAutosaveName("PermissionWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        permissionWindow = window
    }

    // MARK: - Settings Window

    private func showSettingsWindow() {
        // If window already exists, just bring it to front
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView(viewModel: settingsViewModel)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "SimTag Settings"
        window.contentView = hostingView

        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
