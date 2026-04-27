import SwiftUI
import AppKit

struct MenuView: View {
    @Environment(SoundManager.self) private var soundManager
    @Environment(HookManager.self) private var hookManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Section("System Sounds") {
            ForEach(soundManager.systemSounds) { sound in
                Button {
                    soundManager.setSound(sound.path)
                } label: {
                    if soundManager.currentSound == sound.path {
                        Label(sound.name, systemImage: "checkmark")
                    } else {
                        Text(sound.name)
                    }
                }
            }
        }

        if soundManager.isCustomSound {
            Section("Custom") {
                Button {
                    // Already selected — clicking it just re-previews
                    soundManager.playCurrentSound()
                } label: {
                    Label(soundManager.currentSoundDisplayName, systemImage: "checkmark")
                }
            }
        }

        Divider()

        Button("Pick Custom Sound…") {
            soundManager.pickCustomSound()
        }

        if !soundManager.currentSound.isEmpty {
            Button("Preview Current") {
                soundManager.playCurrentSound()
            }
            .keyboardShortcut("p")
            .disabled(!soundManager.hasCurrentSound)

            Button("Clear Sound") {
                soundManager.clearSound()
            }
        }

        Divider()

        Button("Open Claude Chime Window…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        Divider()

        if hookManager.isInstalled {
            Button("Uninstall Stop Hook") {
                hookManager.uninstall()
            }
        } else {
            Button("Install Stop Hook") {
                hookManager.install()
            }
        }

        Button("Reveal settings.json in Finder") {
            hookManager.revealSettingsInFinder()
        }
        .disabled(!hookManager.isInstalled)

        Divider()

        Button("Quit Claude Chime") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
