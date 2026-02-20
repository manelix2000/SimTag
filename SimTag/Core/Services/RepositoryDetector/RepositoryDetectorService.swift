import Foundation

/// Service for detecting git repositories associated with iOS apps running in simulators
protocol RepositoryDetectorService {
    /// Detect the git repository associated with a simulator window
    /// Returns nil if no app is running, app is not from Xcode, or no git repo found
    func detectRepository(for simulator: SimulatorWindow) async throws -> GitRepository?

    /// Read the current branch name from a git repository
    /// Returns nil for detached HEAD state or if branch cannot be determined
    func readCurrentBranch(from repository: GitRepository) throws -> String?
}

/// Errors that can occur during repository detection
enum RepositoryDetectionError: Error {
    case noRunningApp(udid: String)
    case noDerivedDataEntry(bundleID: String)
    case invalidWorkspacePath(path: String)
    case noGitRepository(searchPath: String)
    case invalidGitRepository(path: String)
    case processQueryFailed(Error)
    case derivedDataAccessFailed(Error)
}

extension RepositoryDetectionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noRunningApp(let udid):
            return "No running app found for simulator with UDID: \(udid)"
        case .noDerivedDataEntry(let bundleID):
            return "No DerivedData entry found for bundle ID: \(bundleID)"
        case .invalidWorkspacePath(let path):
            return "Workspace path does not exist: \(path)"
        case .noGitRepository(let searchPath):
            return "No git repository found searching from: \(searchPath)"
        case .invalidGitRepository(let path):
            return "Invalid git repository at: \(path)"
        case .processQueryFailed(let error):
            return "Failed to query running processes: \(error.localizedDescription)"
        case .derivedDataAccessFailed(let error):
            return "Failed to access DerivedData: \(error.localizedDescription)"
        }
    }
}
