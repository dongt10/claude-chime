import SwiftUI
import AppKit
import Observation

@Observable
@MainActor
final class SoundManager {
    static let systemSoundsDirectory = "/System/Library/Sounds"

    /// File extensions afplay (AudioToolbox) can read. Includes audio containers
    /// and the common video containers — afplay extracts the audio track from
    /// MP4/MOV/M4V/3GP. We accept anything in this set when listing a directory;
    /// the file picker is even more permissive (UTType-based).
    private static let supportedExtensions: Set<String> = [
        "aiff", "aif", "aifc",
        "wav", "wave",
        "mp3",
        "m4a", "m4b", "m4r", "m4p",
        "mp4", "m4v", "mov", "3gp", "3gpp",
        "aac", "adts",
        "caf",
        "flac",
        "ac3",
        "amr",
        "au", "snd"
    ]

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
        // .audio covers AIFF/WAV/MP3/M4A/AAC/CAF/FLAC/etc.
        // .audiovisualContent additionally lets the user pick MP4/MOV/M4V/3GP —
        // afplay can read the audio track out of those containers.
        panel.allowedContentTypes = [.audio, .audiovisualContent]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose a sound or video file"
        panel.message = "Anything afplay can read works — most audio formats and most video files (MP4, MOV, M4V) too."

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
