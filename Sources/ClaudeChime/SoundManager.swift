import SwiftUI
import AppKit
import Observation

@Observable
@MainActor
final class SoundManager {
    static let systemSoundsDirectory = "/System/Library/Sounds"
    private static let supportedExtensions: Set<String> = ["aiff", "wav", "mp3", "m4a", "caf", "aac"]

    var currentSound: String = ""

    @ObservationIgnored
    private let configPath: String

    @ObservationIgnored
    private var previewProcess: Process?

    static var defaultConfigPath: String {
        ("~/.claude/notification-sound.txt" as NSString).expandingTildeInPath
    }

    init(configPath: String? = nil) {
        self.configPath = configPath ?? Self.defaultConfigPath
        loadCurrentSound()
    }

    var systemSounds: [Sound] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: Self.systemSoundsDirectory) else {
            return []
        }
        return names
            .filter { Self.supportedExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
            .map { name in
                Sound(
                    name: (name as NSString).deletingPathExtension,
                    path: "\(Self.systemSoundsDirectory)/\(name)"
                )
            }
    }

    var currentSoundDisplayName: String {
        guard !currentSound.isEmpty else { return "None" }
        return Sound.displayName(forPath: currentSound)
    }

    var isCustomSound: Bool {
        !currentSound.isEmpty && !currentSound.hasPrefix(Self.systemSoundsDirectory + "/")
    }

    var hasCurrentSound: Bool {
        !currentSound.isEmpty && FileManager.default.fileExists(atPath: currentSound)
    }

    var currentSoundIsMissing: Bool {
        !currentSound.isEmpty && !FileManager.default.fileExists(atPath: currentSound)
    }

    func loadCurrentSound() {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            if currentSound != "" { currentSound = "" }
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != currentSound {
            currentSound = trimmed
        }
    }

    func setSound(_ path: String) {
        ensureConfigDirectory()
        try? path.write(toFile: configPath, atomically: true, encoding: .utf8)
        currentSound = path
        playPreview(path: path)
    }

    func clearSound() {
        ensureConfigDirectory()
        try? "".write(toFile: configPath, atomically: true, encoding: .utf8)
        currentSound = ""
        stopPreview()
    }

    func playPreview(path: String) {
        stopPreview()
        guard FileManager.default.fileExists(atPath: path) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        task.arguments = [path]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            previewProcess = task
        } catch {
            // Silently ignore — preview is best-effort
        }
    }

    func playCurrentSound() {
        guard hasCurrentSound else { return }
        playPreview(path: currentSound)
    }

    func stopPreview() {
        if let task = previewProcess, task.isRunning {
            task.terminate()
        }
        previewProcess = nil
    }

    func pickCustomSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose a sound file"
        panel.message = "Pick a sound to play when Claude finishes a task"

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            setSound(url.path)
        }
    }

    private func ensureConfigDirectory() {
        let dir = (configPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
    }
}
