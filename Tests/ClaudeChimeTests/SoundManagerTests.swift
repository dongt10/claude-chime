import Testing
import Foundation
@testable import ClaudeChime

@MainActor
struct SoundManagerTests {

    private func makeTempPath() -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudechime-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notification-sound.txt").path
    }

    @Test func loadsEmptyWhenFileMissing() {
        let manager = SoundManager(configPath: makeTempPath())
        #expect(manager.currentSound == "")
        #expect(manager.hasCurrentSound == false)
        #expect(manager.currentSoundDisplayName == "None")
    }

    @Test func loadsExistingValue() throws {
        let path = makeTempPath()
        try "/System/Library/Sounds/Glass.aiff\n".write(toFile: path, atomically: true, encoding: .utf8)

        let manager = SoundManager(configPath: path)
        #expect(manager.currentSound == "/System/Library/Sounds/Glass.aiff")
        #expect(manager.hasCurrentSound == true)
        #expect(manager.currentSoundDisplayName == "Glass")
        #expect(manager.isCustomSound == false)
    }

    @Test func setSoundWritesPathToFile() throws {
        let path = makeTempPath()
        let manager = SoundManager(configPath: path)

        manager.setSound("/System/Library/Sounds/Hero.aiff")

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content == "/System/Library/Sounds/Hero.aiff")
        #expect(manager.currentSound == "/System/Library/Sounds/Hero.aiff")
    }

    @Test func setSoundCreatesParentDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudechime-deep-\(UUID().uuidString)/nested")
        let path = dir.appendingPathComponent("notification-sound.txt").path
        // Note: dir does NOT exist yet
        #expect(!FileManager.default.fileExists(atPath: dir.path))

        let manager = SoundManager(configPath: path)
        manager.setSound("/System/Library/Sounds/Glass.aiff")

        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test func clearSoundEmptiesFile() throws {
        let path = makeTempPath()
        let manager = SoundManager(configPath: path)
        manager.setSound("/System/Library/Sounds/Glass.aiff")

        manager.clearSound()
        #expect(manager.currentSound == "")
        #expect(manager.hasCurrentSound == false)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content == "")
    }

    @Test func loadTrimsWhitespaceAndNewlines() throws {
        let path = makeTempPath()
        try "  /System/Library/Sounds/Glass.aiff  \n\n".write(toFile: path, atomically: true, encoding: .utf8)

        let manager = SoundManager(configPath: path)
        #expect(manager.currentSound == "/System/Library/Sounds/Glass.aiff")
    }

    @Test func detectsCustomSound() throws {
        let path = makeTempPath()
        try "/Users/me/done.mp3".write(toFile: path, atomically: true, encoding: .utf8)

        let manager = SoundManager(configPath: path)
        #expect(manager.isCustomSound == true)
        #expect(manager.currentSoundDisplayName == "done")
    }

    @Test func detectsMissingSoundFile() throws {
        let path = makeTempPath()
        try "/nonexistent/path/sound.aiff".write(toFile: path, atomically: true, encoding: .utf8)

        let manager = SoundManager(configPath: path)
        #expect(!manager.currentSound.isEmpty)
        #expect(manager.hasCurrentSound == false)
        #expect(manager.currentSoundIsMissing == true)
    }

    @Test func systemSoundsDirectoryHasExpectedSounds() {
        let manager = SoundManager(configPath: makeTempPath())
        let names = manager.systemSounds.map(\.name)
        // Sanity check: macOS ships these — if the list is empty the directory enum failed
        #expect(names.contains("Glass"))
        #expect(names.contains("Submarine"))
        #expect(names.count >= 10)
    }
}
