import Foundation

/// FSEvents-based implementation of GitMonitorService
/// Monitors .git/HEAD file for branch changes
/// Source: https://developer.apple.com/documentation/coreservices/file_system_events
class FSEventsGitMonitor: GitMonitorService {

    // MARK: - GitMonitorService Protocol

    var onBranchChanged: ((GitRepository, String?) -> Void)?

    // MARK: - Private Properties

    /// Map of repository path to FSEventStreamRef
    private var eventStreams: [String: FSEventStreamRef] = [:]

    /// Map of repository path to last known branch
    private var lastKnownBranch: [String: String?] = [:]

    /// Dispatch queue for FSEvents callbacks
    private let eventQueue = DispatchQueue(label: "com.simtag.gitmonitor", qos: .utility)

    // MARK: - Lifecycle

    deinit {
        stopAll()
    }

    // MARK: - GitMonitorService Implementation

    func startMonitoring(repository: GitRepository) throws {
        guard repository.isValid else {
            throw GitMonitorError.invalidRepository(path: repository.path.path)
        }

        let repoPath = repository.path.path

        // Don't start monitoring if already monitoring
        guard eventStreams[repoPath] == nil else {
            print("DEBUG GitMonitor: Already monitoring \(repoPath)")
            return
        }

        let gitPath = repository.path.appendingPathComponent(".git").path

        guard FileManager.default.fileExists(atPath: gitPath) else {
            throw GitMonitorError.gitDirectoryNotFound(path: gitPath)
        }

        // Read initial branch state
        let initialBranch = try? readCurrentBranch(from: repository)
        lastKnownBranch[repoPath] = initialBranch

        // Create FSEventStream
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [gitPath] as CFArray
        let callback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let info = clientCallBackInfo else { return }
            let monitor = Unmanaged<FSEventsGitMonitor>.fromOpaque(info).takeUnretainedValue()

            // Safely extract paths from C array
            // eventPaths is a const char ** (array of C strings)
            // This unsafe cast is necessary for FSEvents C API interop
            // The pointer is valid for the duration of the callback
            let pathsPtr = unsafeBitCast(eventPaths, to: UnsafePointer<UnsafePointer<CChar>>.self)
            var detectedPaths: [String] = []

            for i in 0..<Int(numEvents) {
                let cString = pathsPtr[i]
                if let path = String(cString: cString, encoding: .utf8) {
                    detectedPaths.append(path)
                }
            }

            // Find which repository triggered this event
            for path in detectedPaths {
                if path.hasSuffix(".git") || path.contains(".git/") {
                    // Extract repository root path
                    let gitPath = path.components(separatedBy: "/.git").first ?? ""
                    if !gitPath.isEmpty {
                        let repoURL = URL(fileURLWithPath: gitPath)
                        let repo = GitRepository(path: repoURL, isValid: true)
                        monitor.handleFileSystemEvent(for: repo)
                    }
                }
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        ) else {
            throw GitMonitorError.failedToCreateStream(path: gitPath)
        }

        FSEventStreamSetDispatchQueue(stream, eventQueue)

        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            throw GitMonitorError.failedToStartStream(path: gitPath)
        }

        eventStreams[repoPath] = stream
        print("DEBUG GitMonitor: Started monitoring \(repoPath), initial branch: \(initialBranch ?? "nil")")
    }

    func stopMonitoring(repository: GitRepository) {
        let repoPath = repository.path.path

        guard let stream = eventStreams[repoPath] else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)

        eventStreams.removeValue(forKey: repoPath)
        lastKnownBranch.removeValue(forKey: repoPath)

        print("DEBUG GitMonitor: Stopped monitoring \(repoPath)")
    }

    func stopAll() {
        for (_, stream) in eventStreams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }

        eventStreams.removeAll()
        lastKnownBranch.removeAll()

        print("DEBUG GitMonitor: Stopped all monitoring")
    }

    func isMonitoring(repository: GitRepository) -> Bool {
        return eventStreams[repository.path.path] != nil
    }

    // MARK: - Private Methods

    private func handleFileSystemEvent(for repository: GitRepository) {
        let repoPath = repository.path.path

        // Read current branch
        guard let currentBranch = try? readCurrentBranch(from: repository) else {
            print("DEBUG GitMonitor: Failed to read branch for \(repoPath)")
            return
        }

        // Check if branch changed
        if lastKnownBranch[repoPath] != currentBranch {
            let previousStr = lastKnownBranch[repoPath] ?? "nil"
            let currentStr = currentBranch ?? "nil"
            print("DEBUG GitMonitor: Branch changed in \(repoPath): \(previousStr) -> \(currentStr)")

            lastKnownBranch[repoPath] = currentBranch

            // Notify on main thread with repository and branch
            DispatchQueue.main.async { [weak self] in
                self?.onBranchChanged?(repository, currentBranch)
            }
        }
    }

    /// Read current branch from repository
    /// Reuses logic from DerivedDataRepositoryDetector
    private func readCurrentBranch(from repository: GitRepository) throws -> String? {
        let headFile = repository.headFilePath

        guard FileManager.default.fileExists(atPath: headFile.path) else {
            return nil
        }

        let headContent = try String(contentsOf: headFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse HEAD file
        // Format 1: "ref: refs/heads/branch-name" (normal branch)
        // Format 2: "{commit-hash}" (detached HEAD)
        if headContent.hasPrefix("ref: refs/heads/") {
            let branchName = headContent.replacingOccurrences(of: "ref: refs/heads/", with: "")
            return branchName
        } else if headContent.count == 40 {
            // Detached HEAD - return short SHA
            return String(headContent.prefix(7))
        }

        return nil
    }
}

// MARK: - Error Types

enum GitMonitorError: Error, LocalizedError {
    case invalidRepository(path: String)
    case gitDirectoryNotFound(path: String)
    case failedToCreateStream(path: String)
    case failedToStartStream(path: String)

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let path):
            return "Invalid git repository at path: \(path)"
        case .gitDirectoryNotFound(let path):
            return "Git directory not found at path: \(path)"
        case .failedToCreateStream(let path):
            return "Failed to create FSEventStream for path: \(path)"
        case .failedToStartStream(let path):
            return "Failed to start FSEventStream for path: \(path)"
        }
    }
}
