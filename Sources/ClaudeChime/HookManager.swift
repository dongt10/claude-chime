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

    /// The exact command we install. It skips recursive Stop events, then reads
    /// the path from notification-sound.txt and plays it with afplay.
    /// Silently no-ops if the path is missing/empty.
    @ObservationIgnored
    private let hookCommand = #"input=$(cat); active=$(printf '%s' "$input" | /usr/bin/plutil -extract stop_hook_active raw -o - - 2>/dev/null); [ "$active" = true ] && exit 0; f=$(head -n1 "$HOME/.claude/notification-sound.txt" 2>/dev/null); [ -f "$f" ] && /usr/bin/afplay "$f""#

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
        var json = readSettings() ?? [:]
        var hooks = (json["hooks"] as? [String: Any]) ?? [:]
        var stopHooks = (hooks["Stop"] as? [[String: Any]]) ?? []
        let newHook = makeHook()

        var didInstallHook = false
        var updatedStopHooks: [[String: Any]] = []

        for var entry in stopHooks {
            guard let inner = entry["hooks"] as? [[String: Any]] else {
                updatedStopHooks.append(entry)
                continue
            }

            var updatedInner: [[String: Any]] = []
            for hook in inner {
                if isClaudeChimeHook(hook) {
                    if !didInstallHook {
                        updatedInner.append(newHook)
                        didInstallHook = true
                    }
                } else {
                    updatedInner.append(hook)
                }
            }

            if !updatedInner.isEmpty {
                entry["hooks"] = updatedInner
                updatedStopHooks.append(entry)
            }
        }

        if !didInstallHook {
            updatedStopHooks.append(["hooks": [newHook]])
        }

        stopHooks = updatedStopHooks
        hooks["Stop"] = stopHooks
        json["hooks"] = hooks

        writeSettings(json)
        checkInstallation()
    }

    func uninstall() {
        guard locateHook() != nil,
              var json = readSettings(),
              var hooks = json["hooks"] as? [String: Any],
              var stopHooks = hooks["Stop"] as? [[String: Any]] else {
            checkInstallation()
            return
        }

        var updatedStopHooks: [[String: Any]] = []
        for var entry in stopHooks {
            guard var inner = entry["hooks"] as? [[String: Any]] else {
                updatedStopHooks.append(entry)
                continue
            }

            inner.removeAll(where: isClaudeChimeHook)

            if !inner.isEmpty {
                entry["hooks"] = inner
                updatedStopHooks.append(entry)
            }
        }
        stopHooks = updatedStopHooks

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
                if isClaudeChimeHook(hook) {
                    return (i, j)
                }
            }
        }
        return nil
    }

    private func isClaudeChimeHook(_ hook: [String: Any]) -> Bool {
        guard let command = hook["command"] as? String else { return false }
        return command.contains(hookCommandMarker)
    }

    private func makeHook() -> [String: Any] {
        [
            "type": "command",
            "command": hookCommand,
            "async": true,
            "timeout": 30
        ]
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
