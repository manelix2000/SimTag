import SwiftUI

/// SwiftUI view for overlay content
/// Displays git branch info with optional custom label
struct OverlayContentView: View {
    let branchName: String?
    let commitHash: String?
    let timestamp: String?
    let customLabel: String?
    let configuration: OverlayConfiguration

    var body: some View {
        HStack(spacing: 8) {
            // Git branch icon
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: configuration.fontSize))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                // Custom label (if provided)
                if let label = customLabel, !label.isEmpty {
                    Text(label)
                        .font(.system(size: configuration.fontSize - 2, weight: .medium))
                        .foregroundColor(.white)
                }

                // Branch name
                if configuration.showBranchName, let branch = branchName, !branch.isEmpty {
                    Text(branch)
                        .font(.system(size: configuration.fontSize, weight: .medium))
                        .foregroundColor(.white)
                } else if customLabel == nil || customLabel!.isEmpty {
                    // Fallback if no branch and no custom label
                    Text("No Repository")
                        .font(.system(size: configuration.fontSize - 1))
                        .foregroundColor(.gray)
                }

                // Commit hash and timestamp (Phase 6)
                if let hash = commitHash, let time = timestamp {
                    HStack(spacing: 6) {
                        Text("(\(hash))")
                            .font(.system(size: configuration.fontSize - 2))
                            .foregroundColor(.gray)

                        Text(time)
                            .font(.system(size: configuration.fontSize - 2))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .opacity(configuration.opacity)
    }
}

#Preview {
    VStack(spacing: 20) {
        // With branch name
        OverlayContentView(
            branchName: "feature/dark-mode",
            commitHash: "4bfcb0b",
            timestamp: "20h ago",
            customLabel: nil,
            configuration: OverlayConfiguration(
                simulatorKey: "preview",
                position: .topRight
            )
        )

        // With custom label
        OverlayContentView(
            branchName: "main",
            commitHash: nil,
            timestamp: nil,
            customLabel: "PR Review",
            configuration: OverlayConfiguration(
                simulatorKey: "preview",
                position: .topRight
            )
        )

        // No repository
        OverlayContentView(
            branchName: nil,
            commitHash: nil,
            timestamp: nil,
            customLabel: nil,
            configuration: OverlayConfiguration(
                simulatorKey: "preview",
                position: .topRight
            )
        )
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
