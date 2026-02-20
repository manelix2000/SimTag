import SwiftUI

struct PermissionRequestView: View {
    @ObservedObject var permissionManager: PermissionManagerService
    let onClose: () -> Void
    let onPermissionGranted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "display")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            // Title
            Text("Screen Recording Permission Required")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("SimTag needs screen recording permission to detect iOS Simulator windows.")
                    .font(.body)

                Text("This permission is used only to track window positions—SimTag does not record or capture your screen.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Permission status
            if permissionManager.hasPermission {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permission granted")
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if permissionManager.permissionStatus == .denied {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Permission denied")
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                    Text("Please enable Screen Recording in System Settings")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            // Actions
            HStack(spacing: 12) {
                if permissionManager.hasPermission {
                    Button("Close") {
                        onPermissionGranted()
                        onClose()
                    }
                    .keyboardShortcut(.defaultAction)
                } else if permissionManager.permissionStatus == .denied {
                    Button("Open System Settings") {
                        permissionManager.openSystemSettings()
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Check Again") {
                        Task {
                            if await permissionManager.checkPermission() {
                                onPermissionGranted()
                            }
                        }
                    }
                } else {
                    Button("Request Permission") {
                        Task {
                            await permissionManager.requestPermission()
                            if permissionManager.hasPermission {
                                onPermissionGranted()
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Later") {
                        onClose()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    PermissionRequestView(
        permissionManager: PermissionManagerService(),
        onClose: {},
        onPermissionGranted: {}
    )
}
