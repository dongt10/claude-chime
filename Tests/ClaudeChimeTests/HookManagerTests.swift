import Testing
import Foundation
@testable import ClaudeChime

@MainActor
struct HookManagerTests {

    // MARK: - Helpers

    private func makeTempPath() -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudechime-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("settings.json").path
    }

    private func write(_ json: [String: Any], to path: String) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try data.write(to: URL(fileURLWithPath: path))
    }

    private func read(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func stopCommands(in json: [String: Any]) -> [String] {
        let stop = (json["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        return stop?.flatMap { entry in
            (entry["hooks"] as? [[String: Any]])?.compactMap { $0["command"] as? String } ?? []
        } ?? []
    }

    // MARK: - Tests

    @Test func installCreatesEntryWhenNoSettingsFile() throws {
        let path = makeTempPath()
        let manager = HookManager(settingsPath: path)
        #expect(manager.isInstalled == false)

        manager.install()
        #expect(manager.isInstalled == true)

        let json = try read(path)
        let hooks = json["hooks"] as? [String: Any]
        let stop = hooks?["Stop"] as? [[String: Any]]
        #expect(stop?.count == 1)

        let inner = stop?[0]["hooks"] as? [[String: Any]]
        let command = inner?[0]["command"] as? String
        #expect(command?.contains("notification-sound.txt") == true)
        #expect(command?.contains("/usr/bin/afplay") == true)
        #expect(command?.contains("stop_hook_active") == true)
        #expect(command?.contains("/usr/bin/plutil") == true)
        #expect(command?.contains(#""$HOME/.claude/notification-sound.txt""#) == true)
    }

    @Test func installPreservesUnrelatedSettings() throws {
        let path = makeTempPath()
        try write([
            "model": "opus",
            "permissions": ["allow": ["Bash(npm *)"]]
        ], to: path)

        let manager = HookManager(settingsPath: path)
        manager.install()

        let json = try read(path)
        #expect(json["model"] as? String == "opus")
        let perms = json["permissions"] as? [String: Any]
        let allow = perms?["allow"] as? [String]
        #expect(allow == ["Bash(npm *)"])
    }

    @Test func installPreservesOtherStopHooks() throws {
        let path = makeTempPath()
        try write([
            "hooks": [
                "Stop": [
                    [
                        "hooks": [
                            ["type": "command", "command": "echo hello"]
                        ]
                    ]
                ]
            ]
        ], to: path)

        let manager = HookManager(settingsPath: path)
        manager.install()

        let json = try read(path)
        let stop = (json["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        #expect(stop?.count == 2, "should append a new entry without modifying existing")

        // First entry preserved
        let firstInner = stop?[0]["hooks"] as? [[String: Any]]
        #expect(firstInner?[0]["command"] as? String == "echo hello")
    }

    @Test func installIsIdempotent() throws {
        let path = makeTempPath()
        let manager = HookManager(settingsPath: path)

        manager.install()
        manager.install()
        manager.install()

        let json = try read(path)
        let stop = (json["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        #expect(stop?.count == 1, "running install repeatedly must not duplicate the hook")
    }

    @Test func installRepairsLegacyMatchingHooks() throws {
        let path = makeTempPath()
        try write([
            "hooks": [
                "Stop": [
                    ["hooks": [
                        ["type": "command", "command": "cat ~/.claude/notification-sound.txt | xargs afplay"],
                        ["type": "command", "command": "echo other"]
                    ]],
                    ["hooks": [
                        ["type": "command", "command": "f=$(cat ~/.claude/notification-sound.txt); afplay \"$f\""]
                    ]]
                ]
            ]
        ], to: path)

        let manager = HookManager(settingsPath: path)
        manager.install()

        let json = try read(path)
        let commands = stopCommands(in: json)
        let chimeCommands = commands.filter { $0.contains("notification-sound.txt") }

        #expect(chimeCommands.count == 1, "install should collapse legacy duplicates into one current hook")
        #expect(chimeCommands.first?.contains("stop_hook_active") == true)
        #expect(chimeCommands.first?.contains("/usr/bin/plutil") == true)
        #expect(commands.contains("echo other"))
    }

    @Test func uninstallRemovesHook() throws {
        let path = makeTempPath()
        let manager = HookManager(settingsPath: path)
        manager.install()
        #expect(manager.isInstalled == true)

        manager.uninstall()
        #expect(manager.isInstalled == false)

        let json = try read(path)
        // After uninstall with no other hooks, "hooks" key should be gone entirely
        #expect(json["hooks"] == nil)
    }

    @Test func uninstallPreservesOtherStopHooks() throws {
        let path = makeTempPath()
        try write([
            "hooks": [
                "Stop": [
                    ["hooks": [["type": "command", "command": "echo hello"]]]
                ]
            ]
        ], to: path)

        let manager = HookManager(settingsPath: path)
        manager.install()
        manager.uninstall()

        let json = try read(path)
        let stop = (json["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        #expect(stop?.count == 1)
        let inner = stop?[0]["hooks"] as? [[String: Any]]
        #expect(inner?[0]["command"] as? String == "echo hello")
    }

    @Test func uninstallRemovesAllMatchingHooks() throws {
        let path = makeTempPath()
        try write([
            "hooks": [
                "Stop": [
                    ["hooks": [
                        ["type": "command", "command": "cat ~/.claude/notification-sound.txt | xargs afplay"],
                        ["type": "command", "command": "echo hello"]
                    ]],
                    ["hooks": [
                        ["type": "command", "command": "f=$(cat ~/.claude/notification-sound.txt); afplay \"$f\""]
                    ]]
                ]
            ]
        ], to: path)

        let manager = HookManager(settingsPath: path)
        manager.uninstall()

        let json = try read(path)
        let commands = stopCommands(in: json)
        #expect(commands == ["echo hello"])
    }

    @Test func uninstallIsNoopWhenNotInstalled() throws {
        let path = makeTempPath()
        try write(["model": "opus"], to: path)

        let manager = HookManager(settingsPath: path)
        manager.uninstall()

        let json = try read(path)
        #expect(json["model"] as? String == "opus")
    }

    @Test func roundTripPreservesOriginalShape() throws {
        let path = makeTempPath()
        let original: [String: Any] = [
            "model": "sonnet",
            "hooks": [
                "Stop": [
                    ["hooks": [["type": "command", "command": "echo other"]]]
                ],
                "PreToolUse": [
                    ["matcher": "Bash", "hooks": [["type": "command", "command": "echo pre"]]]
                ]
            ]
        ]
        try write(original, to: path)

        let manager = HookManager(settingsPath: path)
        manager.install()
        manager.uninstall()

        let json = try read(path)
        #expect(json["model"] as? String == "sonnet")
        let hooks = json["hooks"] as? [String: Any]
        let stop = hooks?["Stop"] as? [[String: Any]]
        let pre = hooks?["PreToolUse"] as? [[String: Any]]
        #expect(stop?.count == 1)
        #expect(pre?.count == 1)
        #expect((stop?[0]["hooks"] as? [[String: Any]])?[0]["command"] as? String == "echo other")
        #expect((pre?[0]["hooks"] as? [[String: Any]])?[0]["command"] as? String == "echo pre")
    }

    @Test func detectsExistingHookFromMarker() throws {
        let path = makeTempPath()
        try write([
            "hooks": [
                "Stop": [
                    ["hooks": [
                        ["type": "command", "command": "cat ~/.claude/notification-sound.txt | xargs afplay"]
                    ]]
                ]
            ]
        ], to: path)

        let manager = HookManager(settingsPath: path)
        #expect(manager.isInstalled == true, "should recognize any command containing the marker")
    }

    @Test func handlesMalformedSettingsGracefully() throws {
        let path = makeTempPath()
        try "not json {".write(toFile: path, atomically: true, encoding: .utf8)

        let manager = HookManager(settingsPath: path)
        #expect(manager.isInstalled == false)

        // Should not crash — should overwrite with valid JSON
        manager.install()
        let json = try read(path)
        #expect((json["hooks"] as? [String: Any])?["Stop"] != nil)
    }
}
