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
            Text("🔔")
        }
        .menuBarExtraStyle(.menu)

        Window("Claude Chime", id: "main") {
            MainWindow()
                .environment(soundManager)
                .environment(hookManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
