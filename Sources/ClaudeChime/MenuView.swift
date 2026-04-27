import SwiftUI

struct MenuView: View {
    @Environment(SoundManager.self) private var soundManager
    @Environment(HookManager.self) private var hookManager

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()

            if !hookManager.isInstalled {
                HookInstallBanner()
                Divider()
            }

            CurrentSoundRow()
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(soundManager.systemSounds) { sound in
                        SoundRow(sound: sound)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)

            Divider()
            FooterView()
        }
        .frame(width: 300)
        .onAppear {
            soundManager.loadCurrentSound()
            hookManager.checkInstallation()
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .foregroundStyle(.tint)
                .font(.system(size: 14, weight: .semibold))
            Text("Claude Chime")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct HookInstallBanner: View {
    @Environment(HookManager.self) private var hookManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Stop hook not installed")
                    .font(.subheadline.weight(.medium))
            }
            Text("Add the Claude Code Stop hook so the chosen sound plays when Claude finishes a turn.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Install in ~/.claude/settings.json") {
                hookManager.install()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let error = hookManager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.08))
    }
}

private struct CurrentSoundRow: View {
    @Environment(SoundManager.self) private var soundManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Now playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    if soundManager.currentSoundIsMissing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                    Text(soundManager.currentSound.isEmpty ? "None" : soundManager.currentSoundDisplayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if soundManager.isCustomSound && !soundManager.currentSoundIsMissing {
                        Text("(custom)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 8)
            Button {
                soundManager.playCurrentSound()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .disabled(!soundManager.hasCurrentSound)
            .help("Preview current sound")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct SoundRow: View {
    let sound: Sound
    @Environment(SoundManager.self) private var soundManager
    @State private var hovering = false

    private var isSelected: Bool {
        soundManager.currentSound == sound.path
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
            Text(sound.name)
                .font(.system(size: 13))
            Spacer()
            Button {
                soundManager.playPreview(path: sound.path)
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0)
            .help("Preview without selecting")
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(hovering ? Color.gray.opacity(0.12) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { hovering = $0 }
        .onTapGesture {
            soundManager.setSound(sound.path)
        }
    }
}

private struct FooterView: View {
    @Environment(SoundManager.self) private var soundManager
    @Environment(HookManager.self) private var hookManager

    var body: some View {
        HStack(spacing: 6) {
            Button {
                soundManager.pickCustomSound()
            } label: {
                Label("Custom…", systemImage: "folder")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)

            Spacer()

            Menu {
                if hookManager.isInstalled {
                    Button("Uninstall Stop hook", role: .destructive) {
                        hookManager.uninstall()
                    }
                } else {
                    Button("Install Stop hook") {
                        hookManager.install()
                    }
                }
                Button("Reveal settings.json in Finder") {
                    hookManager.revealSettingsInFinder()
                }
                Divider()
                Button("Quit Claude Chime") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
