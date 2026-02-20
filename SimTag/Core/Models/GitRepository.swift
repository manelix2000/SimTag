import Foundation

/// Represents a monitored git repository
struct GitRepository: Identifiable, Equatable, Codable {
    let id: UUID
    let path: URL
    var currentBranch: String?
    var isValid: Bool

    init(
        id: UUID = UUID(),
        path: URL,
        currentBranch: String? = nil,
        isValid: Bool = false
    ) {
        self.id = id
        self.path = path
        self.currentBranch = currentBranch
        self.isValid = isValid
    }

    /// Check if the repository path contains a .git directory
    static func validate(path: URL) -> Bool {
        let gitPath = path.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /// Get the path to the .git/HEAD file
    var headFilePath: URL {
        path.appendingPathComponent(".git/HEAD")
    }
}
