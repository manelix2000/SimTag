import Foundation

/// Service for monitoring git repository changes
/// Watches for branch switches, commits, and other git state changes
protocol GitMonitorService {
    /// Callback invoked when the current branch changes
    /// - Parameters:
    ///   - repository: The repository that changed
    ///   - branchName: The new branch name, or nil if detached HEAD or error
    var onBranchChanged: ((GitRepository, String?) -> Void)? { get set }

    /// Start monitoring a git repository
    /// - Parameter repository: The git repository to monitor
    /// - Throws: If monitoring cannot be started (invalid path, permission issues)
    func startMonitoring(repository: GitRepository) throws

    /// Stop monitoring a specific repository
    /// - Parameter repository: The repository to stop monitoring
    func stopMonitoring(repository: GitRepository)

    /// Stop monitoring all repositories
    func stopAll()

    /// Check if a repository is currently being monitored
    /// - Parameter repository: The repository to check
    /// - Returns: true if the repository is being monitored
    func isMonitoring(repository: GitRepository) -> Bool
}
