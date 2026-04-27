import SwiftUI
import AppKit
import Observation

@Observable
@MainActor
final class HookManager {
    var isInstalled: Bool = false
    var lastError: String? = nil

    @ObservationIgnored
    private let settingsPath: String

    /// Substring used to recognize our hook in settings.json.
    @ObservationIgnored
    private let hookCommandMarker = "notification-sound.txt"

    /// The exact command we install. Reads the path from notification-sound.txt
    /// and plays it with afplay. Silently no-ops if the path is missing/empty.
    @ObservationIgnored
    private let hookCommand = #"f=$(cat ~/.claude/notification-sound.txt 2>/dev/null | head -n1 | tr -d '\r\n '); [ -f "$f" ] && afplay "$f""#

    static var defaultSettingsPath: String {
        ("~/.claude/settings.json" as NSString).expandingTildeInPath
    }

    init(settingsPath: String? = nil) {
        self.settingsPath = settingsPath ?? Self.defaultSettingsPath
        checkInstallation()
    }

    func checkInstallation() {
        isInstalled = locateHook() != nil
    }

    func install() {
        if locateHook() != nil {
            checkInstallation()
            return
        }

        var json = readSettings() ?? [:]
        var hooks = (json["hooks"] as? [String: Any]) ?? [:]
        var stopHooks = (hooks["Stop"] as? [[String: Any]]) ?? []

        let newHook: [String: Any] = [
            "type": "command",
            "command": hookCommand,
            "async": true,
            "timeout": 30
        ]
        stopHooks.append(["hooks": [newHook]])
        hooks["Stop"] = stopHooks
        json["hooks"] = hooks

        writeSettings(json)
        checkInstallation()
    }

    func uninstall() {
        guard let location = locateHook(),
              var json = readSettings(),
              var hooks = json["hooks"] as? [String: Any],
              var stopHooks = hooks["Stop"] as? [[String: Any]] else {
            checkInstallation()
            return
        }

        var entry = stopHooks[location.entryIndex]
        guard var inner = entry["hooks"] as? [[String: Any]] else { return }
        inner.remove(at: location.hookIndex)

        if inner.isEmpty {
            stopHooks.remove(at: location.entryIndex)
        } else {
            entry["hooks"] = inner
            stopHooks[location.entryIndex] = entry
        }

        if stopHooks.isEmpty {
            hooks.removeValue(forKey: "Stop")
        } else {
            hooks["Stop"] = stopHooks
        }

        if hooks.isEmpty {
            json.removeValue(forKey: "hooks")
        } else {
            json["hooks"] = hooks
        }

        writeSettings(json)
        checkInstallation()
    }

    func revealSettingsInFinder() {
        guard FileManager.default.fileExists(atPath: settingsPath) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: settingsPath)])
    }

    private func locateHook() -> (entryIndex: Int, hookIndex: Int)? {
        guard let json = readSettings(),
              let hooks = json["hooks"] as? [String: Any],
              let stop = hooks["Stop"] as? [[String: Any]] else {
            return nil
        }
        for (i, entry) in stop.enumerated() {
            guard let inner = entry["hooks"] as? [[String: Any]] else { continue }
            for (j, hook) in inner.enumerated() {
                if let command = hook["command"] as? String,
                   command.contains(hookCommandMarker) {
                    return (i, j)
                }
            }
        }
        return nil
    }

    private func readSettings() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: settingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func writeSettings(_ json: [String: Any]) {
        let dir = (settingsPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
        do {
            let data = try JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: URL(fileURLWithPath: settingsPath))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
