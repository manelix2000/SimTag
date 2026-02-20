import SwiftUI

/// Settings window view matching the provided design
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(Color.gray.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Simulators list
                    simulatorsList

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // Position selector
                    positionSelector
                }
                .padding(20)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Footer
            footer
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SimTag")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
                .overlay(
                    HStack {
                        Text("Launch at Login")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.trailing, 60)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Simulators List

    private var simulatorsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(viewModel.activeSimulators.count) simulators active")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            if viewModel.activeSimulators.isEmpty {
                Text("No simulators running")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.activeSimulators) { simulator in
                        SimulatorRow(
                            simulator: simulator,
                            isSelected: viewModel.selectedSimulator?.id == simulator.id,
                            action: {
                                viewModel.selectSimulator(simulator)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Position Selector

    private var positionSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overlay Position")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            // Grid of position options in 2 rows of 3
            VStack(spacing: 28) {
                // Top row
                HStack(spacing: 36) {
                    Spacer()
                    PositionButton(
                        position: .topLeft,
                        isSelected: viewModel.selectedPosition == .topLeft,
                        action: { viewModel.selectedPosition = .topLeft }
                    )

                    PositionButton(
                        position: .topCenter,
                        isSelected: viewModel.selectedPosition == .topCenter,
                        action: { viewModel.selectedPosition = .topCenter }
                    )

                    PositionButton(
                        position: .topRight,
                        isSelected: viewModel.selectedPosition == .topRight,
                        action: { viewModel.selectedPosition = .topRight }
                    )
                    Spacer()
                }

                // Bottom row
                HStack(spacing: 36) {
                    Spacer()
                    PositionButton(
                        position: .bottomLeft,
                        isSelected: viewModel.selectedPosition == .bottomLeft,
                        action: { viewModel.selectedPosition = .bottomLeft }
                    )

                    PositionButton(
                        position: .bottomCenter,
                        isSelected: viewModel.selectedPosition == .bottomCenter,
                        action: { viewModel.selectedPosition = .bottomCenter }
                    )

                    PositionButton(
                        position: .bottomRight,
                        isSelected: viewModel.selectedPosition == .bottomRight,
                        action: { viewModel.selectedPosition = .bottomRight }
                    )
                    Spacer()
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Feedback") {
                // TODO: Open feedback URL
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Text("•")
                .foregroundColor(.secondary)

            Button("Check for updates") {
                // TODO: Check for updates
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button("Quit") {
                viewModel.quit()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Simulator Row

struct SimulatorRow: View {
    let simulator: SimulatorWindow
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: "iphone")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    // Device name
                    Text(simulator.deviceName)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)

                    // Branch name
                    if let branch = simulator.associatedRepository?.currentBranch {
                        Text(branch)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        Text("No repository")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Position Button

struct PositionButton: View {
    let position: OverlayConfiguration.Position
    let isSelected: Bool
    let action: () -> Void
    
    var alignment: Alignment {
        switch position {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        case .topCenter: return .top
        case .bottomCenter: return .bottom
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                ZStack {
                    // Phone shape (simulator representation)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 70, height: 110)
                        .overlay(
                            // Phone notch
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 35, height: 5).padding(5),
                            alignment: alignment
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2.5 : 1)
                        )

                }
            }
            .buttonStyle(.plain)

            Text(position.displayName)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .fontWeight(isSelected ? .medium : .regular)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(viewModel: SettingsViewModel())
        .preferredColorScheme(.dark)
}
