import Foundation

/// Implementation of RepositoryDetectorService using DerivedData mapping
/// Detects running apps via process monitoring and maps them to source code via Xcode DerivedData
class DerivedDataRepositoryDetector: RepositoryDetectorService {

    // MARK: - Process Cache

    private struct ProcessCacheEntry {
        let bundleID: String
        let timestamp: Date
    }

    private var processCache: [String: ProcessCacheEntry] = [:]  // UDID -> ProcessCacheEntry
    private let cacheTTL:  TimeInterval = 30.0  // 30 seconds

    // MARK: - DerivedData Index

    private struct DerivedDataProject {
        let workspacePath: URL
        let bundleID: String
        let lastAccessDate: Date
    }

    private var derivedDataIndex: [String: [DerivedDataProject]]?  // Bundle ID -> [Projects]
    private let derivedDataPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/Xcode/DerivedData")

    // MARK: - RepositoryDetectorService Implementation

    func detectRepository(for simulator: SimulatorWindow) async throws -> GitRepository? {
        print("DEBUG RepositoryDetector: Starting detection for UDID: \(simulator.deviceUDID)")

        // Step 1: Get running app bundle ID
        guard let appBundleID = try await getRunningAppBundleID(for: simulator.deviceUDID) else {
            print("DEBUG RepositoryDetector: No running app found for UDID: \(simulator.deviceUDID)")
            throw RepositoryDetectionError.noRunningApp(udid: simulator.deviceUDID)
        }
        print("DEBUG RepositoryDetector: Found app bundle ID: \(appBundleID)")

        // Step 2: Find workspace path via DerivedData
        guard let workspacePath = try await findWorkspacePath(for: appBundleID) else {
            print("DEBUG RepositoryDetector: No DerivedData entry for bundle ID: \(appBundleID)")
            throw RepositoryDetectionError.noDerivedDataEntry(bundleID: appBundleID)
        }
        print("DEBUG RepositoryDetector: Found workspace path: \(workspacePath.path)")

        // Step 3: Find git repository from workspace
        guard let gitRepoPath = findGitRepository(from: workspacePath) else {
            print("DEBUG RepositoryDetector: No git repository found from workspace: \(workspacePath.path)")
            throw RepositoryDetectionError.noGitRepository(searchPath: workspacePath.path)
        }
        print("DEBUG RepositoryDetector: Found git repository: \(gitRepoPath.path)")

        // Step 4: Validate and create repository
        let isValid = GitRepository.validate(path: gitRepoPath)
        let repository = GitRepository(path: gitRepoPath, isValid: isValid)
        guard repository.isValid else {
            print("DEBUG RepositoryDetector: Invalid git repository at: \(gitRepoPath.path)")
            throw RepositoryDetectionError.invalidGitRepository(path: gitRepoPath.path)
        }

        // Step 5: Read current branch
        var repoWithBranch = repository
        repoWithBranch.currentBranch = try? readCurrentBranch(from: repository)
        print("DEBUG RepositoryDetector: Current branch: \(repoWithBranch.currentBranch ?? "nil")")

        return repoWithBranch
    }

    func readCurrentBranch(from repository: GitRepository) throws -> String? {
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

    // MARK: - Step 1: Process Monitoring

    private func getRunningAppBundleID(for udid: String) async throws -> String? {
        // Check cache first
        if let cached = processCache[udid],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.bundleID
        }

        // Query processes
        let bundleID = try await queryRunningProcesses(for: udid)

        // Update cache
        if let bundleID = bundleID {
            processCache[udid] = ProcessCacheEntry(bundleID: bundleID, timestamp: Date())
        }

        return bundleID
    }

    private func queryRunningProcesses(for udid: String) async throws -> String? {
        print("DEBUG ProcessScanner: Scanning processes for UDID: \(udid)")

        // Run ps aux asynchronously on a background queue to avoid blocking
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/ps")
                process.arguments = ["aux"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    print("DEBUG ProcessScanner: Starting ps process...")
                    try process.run()
                    print("DEBUG ProcessScanner: Process started, reading output...")

                    // Read data BEFORE waiting (to prevent pipe buffer deadlock)
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    print("DEBUG ProcessScanner: Output read, waiting for process to exit...")

                    process.waitUntilExit()
                    print("DEBUG ProcessScanner: ps completed with status: \(process.terminationStatus)")

                    guard let output = String(data: data, encoding: .utf8) else {
                        print("DEBUG ProcessScanner: Failed to decode process output")
                        continuation.resume(returning: nil)
                        return
                    }

                    // First, let's see ALL simulator-related processes
                    let lines = output.components(separatedBy: "\n")
                    print("DEBUG ProcessScanner: Checking \(lines.count) processes total")

            var simulatorProcesses: [String] = []
            for line in lines {
                if line.contains("Simulator") || line.contains("CoreSimulator") || line.contains(udid) {
                    simulatorProcesses.append(line)
                }
            }

            if !simulatorProcesses.isEmpty {
                print("DEBUG ProcessScanner: Found \(simulatorProcesses.count) simulator-related processes:")
                for (index, proc) in simulatorProcesses.prefix(10).enumerated() {
                    print("  [\(index)] \(proc)")
                }
            }

            // Parse process list for simulator app processes
            // Looking for: /Users/.../CoreSimulator/Devices/{UDID}/data/Containers/Bundle/Application/{ID}/MyApp.app/MyApp
            var matchingLines: [String] = []
            for line in lines {
                if line.contains(udid) && line.contains(".app/") {
                    matchingLines.append(line)
                    print("DEBUG ProcessScanner: Found matching process: \(line)")
                    // Extract bundle ID from process path
                    if let bundleID = self?.extractBundleID(from: line, udid: udid) {
                        print("DEBUG ProcessScanner: Extracted bundle ID: \(bundleID)")
                        continuation.resume(returning: bundleID)
                        return
                    }
                }
            }

            if matchingLines.isEmpty {
                print("DEBUG ProcessScanner: No processes found matching UDID and .app/")
                print("DEBUG ProcessScanner: This usually means no app is running in the simulator (just home screen)")
            } else {
                print("DEBUG ProcessScanner: Found \(matchingLines.count) matching processes but couldn't extract bundle ID")
            }

            continuation.resume(returning: nil)
                } catch {
                    print("DEBUG ProcessScanner: ERROR executing ps command: \(error)")
                    continuation.resume(throwing: RepositoryDetectionError.processQueryFailed(error))
                }
            }
        }
    }

    // MARK: - Step 2: Bundle ID Extraction

    private func extractBundleID(from processLine: String, udid: String) -> String? {
        // Process line format:
        // user  PID ... /path/to/CoreSimulator/Devices/{UDID}/data/Containers/Bundle/Application/{ID}/MyApp.app/MyApp

        // Find the app bundle path in the line
        guard let appRange = processLine.range(of: ".app/") else {
            return nil
        }

        // Extract everything up to and including .app
        let pathEnd = appRange.upperBound
        let pathComponents = processLine[..<pathEnd].components(separatedBy: " ")

        // Find the component that contains the full path to .app
        for component in pathComponents.reversed() {
            if component.contains(".app") && component.contains(udid) {
                // Extract the .app bundle path
                if let appStart = component.range(of: "/Users/") {
                    let fullPath = String(component[appStart.lowerBound...])
                    // Remove trailing "/" from ".app/"
                    let appPath = fullPath.replacingOccurrences(of: "/.app/", with: ".app")
                        .replacingOccurrences(of: ".app/", with: ".app")

                    // Read CFBundleIdentifier from Info.plist
                    let infoPlistPath = appPath + "/Info.plist"
                    return readBundleIDFromInfoPlist(at: infoPlistPath)
                }
            }
        }

        return nil
    }

    private func readBundleIDFromInfoPlist(at path: String) -> String? {
        print("DEBUG BundleIDExtractor: Reading Info.plist at: \(path)")

        guard FileManager.default.fileExists(atPath: path) else {
            print("DEBUG BundleIDExtractor: Info.plist not found at path")
            return nil
        }

        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
              ) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            print("DEBUG BundleIDExtractor: Failed to read CFBundleIdentifier from plist")
            return nil
        }

        print("DEBUG BundleIDExtractor: Successfully read bundle ID: \(bundleID)")
        return bundleID
    }

    // MARK: - Step 3: DerivedData Search

    private func findWorkspacePath(for bundleID: String) async throws -> URL? {
        // Build index if needed
        if derivedDataIndex == nil {
            try await buildDerivedDataIndex()
        }

        // Find matching projects
        guard let projects = derivedDataIndex?[bundleID], !projects.isEmpty else {
            return nil
        }

        // If multiple matches, use most recently accessed
        let mostRecent = projects.max(by: { $0.lastAccessDate < $1.lastAccessDate })
        return mostRecent?.workspacePath
    }

    private func buildDerivedDataIndex() async throws {
        var index: [String: [DerivedDataProject]] = [:]

        guard FileManager.default.fileExists(atPath: derivedDataPath.path) else {
            derivedDataIndex = index
            return
        }

        do {
            let projectDirs = try FileManager.default.contentsOfDirectory(
                at: derivedDataPath,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            for projectDir in projectDirs {
                let infoPlistPath = projectDir.appendingPathComponent("info.plist")

                guard FileManager.default.fileExists(atPath: infoPlistPath.path) else {
                    continue
                }

                // Read info.plist
                if let plistData = try? Data(contentsOf: infoPlistPath),
                   let plist = try? PropertyListSerialization.propertyList(
                    from: plistData,
                    options: [],
                    format: nil
                   ) as? [String: Any] {

                    // Extract WorkspacePath
                    guard let workspacePath = plist["WorkspacePath"] as? String else {
                        continue
                    }

                    let workspaceURL = URL(fileURLWithPath: workspacePath)

                    // Get last access date
                    let modificationDate = (try? projectDir.resourceValues(forKeys: [.contentModificationDateKey]))? .contentModificationDate ?? Date.distantPast

                    // Try to find bundle ID by reading project files
                    // For now, we'll need to scan Build/Products for .app bundles
                    if let bundleIDs = findBundleIDsInDerivedData(projectDir: projectDir) {
                        for bundleID in bundleIDs {
                            let project = DerivedDataProject(
                                workspacePath: workspaceURL,
                                bundleID: bundleID,
                                lastAccessDate: modificationDate
                            )

                            if index[bundleID] == nil {
                                index[bundleID] = []
                            }
                            index[bundleID]?.append(project)
                        }
                    }
                }
            }

            derivedDataIndex = index
        } catch {
            throw RepositoryDetectionError.derivedDataAccessFailed(error)
        }
    }

    private func findBundleIDsInDerivedData(projectDir: URL) -> [String]? {
        let buildProductsPath = projectDir.appendingPathComponent("Build/Products")

        guard FileManager.default.fileExists(atPath: buildProductsPath.path) else {
            return nil
        }

        var bundleIDs: Set<String> = []

        // Scan for .app bundles in ALL iphonesimulator build configurations
        // (not just Debug - could be Debug-iphonesimulator, Release-iphonesimulator, Develop-Brazil-iphonesimulator, etc.)
        guard let buildConfigs = try? FileManager.default.contentsOfDirectory(
            at: buildProductsPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for configDir in buildConfigs where configDir.lastPathComponent.hasSuffix("-iphonesimulator") {
            if let apps = try? FileManager.default.contentsOfDirectory(
                at: configDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for app in apps where app.pathExtension == "app" {
                    if let bundleID = readBundleIDFromApp(at: app) {
                        bundleIDs.insert(bundleID)
                    }
                }
            }
        }

        return bundleIDs.isEmpty ? nil : Array(bundleIDs)
    }

    private func readBundleIDFromApp(at appPath: URL) -> String? {
        let infoPlistPath = appPath.appendingPathComponent("Info.plist")

        guard FileManager.default.fileExists(atPath: infoPlistPath.path) else {
            return nil
        }

        guard let plistData = try? Data(contentsOf: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return nil
        }

        return plist["CFBundleIdentifier"] as? String
    }

    // MARK: - Step 4: Git Repository Discovery

    private func findGitRepository(from startPath: URL) -> URL? {
        var currentPath = startPath

        // Traverse up the directory tree looking for .git
        while currentPath.path != "/" {
            let gitPath = currentPath.appendingPathComponent(".git")

            if FileManager.default.fileExists(atPath: gitPath.path) {
                return currentPath
            }

            currentPath = currentPath.deletingLastPathComponent()
        }

        return nil
    }
}
