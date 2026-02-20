import Foundation

/// Coordinator that orchestrates repository detection for simulator windows
/// Listens to window changes, detects repositories, and updates simulator windows with repository info
@MainActor
class RepositoryCoordinator {

    // MARK: - Dependencies

    private let repositoryDetector: RepositoryDetectorService

    // MARK: - State

    private var detectionInProgress: Set<UUID> = []  // Track windows being processed

    // MARK: - Initialization

    init(repositoryDetector: RepositoryDetectorService) {
        self.repositoryDetector = repositoryDetector
    }

    // MARK: - Window Change Handling

    /// Handle window changes by detecting repositories for new or updated windows
    /// Updates the simulator windows in-place with detected repository information
    func handleWindowsChanged(_ windows: inout [SimulatorWindow]) async {
        // Detect repositories in parallel for all windows
        await withTaskGroup(of: (UUID, GitRepository?).self) { group in
            for window in windows {
                // Skip if already detecting for this window
                guard !detectionInProgress.contains(window.id) else {
                    continue
                }

                // Skip if we already have a repository for this window
                guard window.associatedRepository == nil else {
                    continue
                }

                detectionInProgress.insert(window.id)

                group.addTask {
                    let repository = try? await self.repositoryDetector.detectRepository(for: window)
                    return (window.id, repository)
                }
            }

            // Collect results and update windows
            for await (windowID, repository) in group {
                detectionInProgress.remove(windowID)

                if let index = windows.firstIndex(where: { $0.id == windowID }) {
                    windows[index].associatedRepository = repository

                    if let repo = repository {
                        print("INFO: Detected repository for window \(windowID): \(repo.path.lastPathComponent), branch: \(repo.currentBranch ?? "nil")")
                    } else {
                        print("DEBUG: No repository detected for window \(windowID)")
                    }
                }
            }
        }
    }

    /// Force re-detection of repositories for all windows
    /// Useful for refreshing repository information
    func refreshRepositories(for windows: inout [SimulatorWindow]) async {
        // Clear existing repositories
        for index in windows.indices {
            windows[index].associatedRepository = nil
        }

        // Re-detect
        await handleWindowsChanged(&windows)
    }
}
