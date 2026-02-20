import SwiftUI

@main
struct SimTagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app - no windows needed in Scene
        Settings {
            EmptyView()
        }
    }
}
