import SwiftUI

@main
struct ClaudeChimeApp: App {
    @State private var soundManager = SoundManager()
    @State private var hookManager = HookManager()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(soundManager)
                .environment(hookManager)
        } label: {
            Image(systemName: "bell.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
