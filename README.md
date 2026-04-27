# Claude Chime

A tiny native macOS menu bar app that plays a sound when Claude Code finishes a task. Pick from any built-in macOS system sound or your own audio file — no editing JSON.

![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey) ![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

## What it does

Claude Code fires a `Stop` hook every time the assistant finishes responding. Claude Chime ships a one-line `afplay` hook and a friendly UI for picking which sound it plays. Selection is stored in a plain text file (`~/.claude/notification-sound.txt`) so the hook stays portable and inspectable.

Features:

- Lives in the menu bar — no Dock icon, no window clutter (`LSUIElement`).
- Browse the 14 built-in macOS system sounds, with one-click previews.
- Hover any row for a preview button that doesn't change your selection.
- Pick a custom file in any format `afplay` can read — see below.
- Detects whether the Stop hook is wired up; installs/uninstalls it for you.
- Cleanly merges into an existing `~/.claude/settings.json` — preserves any other hooks you have.

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode 15.3+ command line tools (`xcode-select --install`) — Swift 5.10+
- [Claude Code](https://claude.com/claude-code) installed

## Install

Build from source:

```bash
git clone https://github.com/<your-username>/claude-chime.git
cd claude-chime
./build.sh
mv ClaudeChime.app /Applications/
open /Applications/ClaudeChime.app
```

### Bypassing Gatekeeper on first launch

The build script ad-hoc signs the binary but doesn't notarize it (notarization requires a paid Apple Developer ID). On macOS 15+ (Sequoia, Sonoma, Tahoe…) Gatekeeper refuses to launch ad-hoc-signed apps from Finder until you grant a one-time exception:

1. Double-click `ClaudeChime.app`. You'll see *"…cannot be opened because Apple cannot check it for malicious software."* Click **Done**.
2. Open **System Settings → Privacy & Security**, scroll to the bottom, find the line about ClaudeChime, and click **Open Anyway**. Authenticate.
3. Confirm in the dialog. From now on, double-click works.

If you'd rather skip the System Settings dance, launch it once from a terminal — `open` is more permissive than Finder for ad-hoc-signed apps:

```bash
open /Applications/ClaudeChime.app
```

> **Note for older macOS:** the right-click → **Open** trick still works on macOS 13/14. The `xattr -dr com.apple.quarantine` workaround does *not* help on Tahoe because the blocker is `com.apple.provenance`, which the OS re-applies automatically.

## Usage

1. Click the bell icon in the menu bar.
2. If the orange banner shows up, click **Install in ~/.claude/settings.json** — this adds the Stop hook.
3. Click any sound to make it the current one (it auto-previews).
4. Hover a sound and click the small play icon to preview without changing your selection.
5. Use **Custom…** to pick any audio file outside the system library.

To **disable** the chime without uninstalling the app, open the popover → `…` menu → **Uninstall Stop hook**. Reinstall the same way.

## Supported file formats

Claude Chime plays your sound with macOS's `afplay`, which is built on the AudioToolbox framework. That gives broad format coverage out of the box.

**Audio formats** (well supported):

| Format | Extensions |
| --- | --- |
| AIFF | `.aiff`, `.aif`, `.aifc` |
| WAV | `.wav`, `.wave` |
| MP3 | `.mp3` |
| AAC / MPEG-4 audio | `.m4a`, `.m4b`, `.m4r`, `.aac` |
| Apple Lossless (ALAC) | `.m4a` |
| Apple Core Audio | `.caf` |
| FLAC | `.flac` |
| AC-3 (Dolby Digital) | `.ac3` (limited — depends on macOS version) |
| µ-law / A-law / IMA4 | usually inside `.aiff` or `.wav` |

**Video containers** (audio track is extracted):

| Format | Extensions |
| --- | --- |
| MPEG-4 / H.264 | `.mp4`, `.m4v` |
| QuickTime | `.mov` |
| 3GPP | `.3gp`, `.3gpp` |

**Not supported**: Ogg Vorbis (`.ogg`), Opus (`.opus`), WMA. Convert to one of the above first if you need them.

If you pick something `afplay` can't read, the hook silently does nothing — it never blocks Claude. You can verify a file works by running `afplay /path/to/your/file` from a terminal.

## How it works

On install, Claude Chime adds this entry to your `~/.claude/settings.json`:

```jsonc
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=$(cat ~/.claude/notification-sound.txt 2>/dev/null | head -n1 | tr -d '\\r\\n '); [ -f \"$f\" ] && afplay \"$f\"",
            "async": true,
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

When Claude Code finishes a turn, it runs this hook. The hook reads the path stored in `~/.claude/notification-sound.txt` and plays it with `afplay`. If the file is missing, empty, or the path doesn't resolve, the hook silently does nothing — it never blocks Claude.

The app only writes to two files:

| File | Purpose |
| --- | --- |
| `~/.claude/notification-sound.txt` | Absolute path to the chosen sound |
| `~/.claude/settings.json` | Stop hook entry (only on install/uninstall) |

You can edit `notification-sound.txt` directly while the app is open — the popover refreshes when reopened.

## Note on hook reload

Claude Code's settings watcher only picks up files that existed when a session started. If you install the hook for the first time while a Claude Code session is running, open `/hooks` once or restart Claude to pick it up. Subsequent sessions detect it automatically.

## Build details

Pure Swift Package Manager. No third-party dependencies. The `build.sh` wrapper produces a universal (`arm64` + `x86_64`) `.app` bundle and ad-hoc-signs it. For a notarized release, plug in your Developer ID via `codesign --sign "Developer ID Application: …"` and `xcrun notarytool`.

```
claude-chime/
├── Package.swift              # SwiftPM manifest, macOS 14+
├── Info.plist                 # LSUIElement = true (menu bar only)
├── build.sh                   # Builds .app bundle
├── Sources/ClaudeChime/
│   ├── ClaudeChimeApp.swift   # @main App + MenuBarExtra
│   ├── MenuView.swift         # Popover UI
│   ├── SoundManager.swift     # Sound IO + afplay preview
│   ├── HookManager.swift      # settings.json read/merge/write
│   └── Models.swift
```

## Contributing

PRs welcome. Some open ideas:

- Custom app icon / `.icns` (currently uses generic)
- Per-event sounds (separate sound for `Notification`, `PreCompact`, etc.)
- Volume slider
- Launch-at-login toggle (`SMAppService`)
- Homebrew Cask formula

## License

MIT — see [LICENSE](LICENSE).
