import SwiftUI
import AppKit

struct MainWindow: View {
    @Environment(SoundManager.self) private var soundManager
    @Environment(HookManager.self) private var hookManager

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StatusCard()
                    NowPlayingCard()
                    SoundsSection()
                }
                .padding(20)
            }

            Divider()
            FooterBar()
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 500, idealHeight: 620)
        .onAppear {
            soundManager.loadCurrentSound()
            hookManager.checkInstallation()
        }
    }
}

private struct HeaderBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("🔔")
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 1) {
                Text("Claude Chime")
                    .font(.title2.weight(.semibold))
                Text("A sound for every finish.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct StatusCard: View {
    @Environment(HookManager.self) private var hookManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hookManager.isInstalled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(hookManager.isInstalled ? Color.green : Color.orange)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text(hookManager.isInstalled ? "Stop hook installed" : "Stop hook not installed")
                    .font(.subheadline.weight(.medium))
                Text(hookManager.isInstalled
                     ? "Claude Code will play your chosen sound when it finishes a turn."
                     : "Install the hook so Claude Code knows to play the sound on finish.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if hookManager.isInstalled {
                Button("Uninstall", role: .destructive) {
                    hookManager.uninstall()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Install") {
                    hookManager.install()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hookManager.isInstalled ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder((hookManager.isInstalled ? Color.green : Color.orange).opacity(0.25), lineWidth: 1)
        )
    }
}

private struct NowPlayingCard: View {
    @Environment(SoundManager.self) private var soundManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now playing")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if soundManager.currentSoundIsMissing {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        Text(soundManager.currentSound.isEmpty ? "No sound chosen" : soundManager.currentSoundDisplayName)
                            .font(.title3.weight(.medium))
                            .lineLimit(1)
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    soundManager.playCurrentSound()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .disabled(!soundManager.hasCurrentSound)
                .help("Preview")
            }
        }
    }

    private var subtitle: String {
        if soundManager.currentSound.isEmpty {
            return "Pick one below"
        }
        if soundManager.currentSoundIsMissing {
            return "File not found at \(soundManager.currentSound)"
        }
        return soundManager.isCustomSound ? "Custom sound" : "macOS system sound"
    }
}

private struct SoundsSection: View {
    @Environment(SoundManager.self) private var soundManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("System sounds")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(soundManager.systemSounds.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 2) {
                ForEach(soundManager.systemSounds) { sound in
                    BigSoundRow(sound: sound)
                }
            }

            HStack {
                Button {
                    soundManager.pickCustomSound()
                } label: {
                    Label("Pick custom sound…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                if !soundManager.currentSound.isEmpty {
                    Button("Clear", role: .destructive) {
                        soundManager.clearSound()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct BigSoundRow: View {
    let sound: Sound
    @Environment(SoundManager.self) private var soundManager
    @State private var hovering = false

    private var isSelected: Bool {
        soundManager.currentSound == sound.path
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                }
            }

            Text(sound.name)
                .font(.body)

            Spacer()

            Button {
                soundManager.playPreview(path: sound.path)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .opacity(hovering || isSelected ? 1 : 0.35)
            .help("Preview without selecting")
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.10)
                      : (hovering ? Color.gray.opacity(0.10) : Color.clear))
        )
        .onHover { hovering = $0 }
        .onTapGesture {
            soundManager.setSound(sound.path)
        }
    }
}

private struct FooterBar: View {
    @Environment(HookManager.self) private var hookManager

    var body: some View {
        HStack {
            Button {
                hookManager.revealSettingsInFinder()
            } label: {
                Label("Reveal settings.json", systemImage: "magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(!hookManager.isInstalled)

            Spacer()

            Text("v1.0")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
