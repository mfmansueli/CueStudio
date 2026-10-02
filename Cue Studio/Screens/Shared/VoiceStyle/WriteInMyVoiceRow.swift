//
//  WriteInMyVoiceRow.swift
//  Cue Studio
//

import SwiftUI

/// "Write in my voice" inside the idea card: a quiet row with a switch, and, while it is on, a small
/// way to edit the style. The switch is the same state as Generate's and Profile's
/// (`CreatorProfileService.writesInMyVoice`). Turning it on without enough in the profile opens the
/// short setup instead, and the switch stays off until it is saved.
struct WriteInMyVoiceRow: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(DictationService.self) private var dictation
    @State private var setup: VoiceSetupSheet.Mode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: profile.writesInMyVoiceBinding(needsSetup: requestSetup)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Write in my voice")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Uses your creator profile.")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .tint(Palette.successText)
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityIdentifier("empty.voiceToggle")
            if profile.writesInMyVoice {
                Button { setup = .edit } label: {
                    Text("Edit style")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("empty.editStyleButton")
            }
        }
        .animation(.smooth(duration: 0.2), value: profile.writesInMyVoice)
        .sheet(item: $setup) { mode in
            VoiceSetupSheet(mode: mode, profile: profile.profile)
        }
    }

    // MARK: - Actions

    /// Opens the setup. A dictation still finishing gets to write its last words first, so the
    /// transcription is whole before another sheet takes the screen.
    private func requestSetup() {
        guard dictation.isActive else {
            setup = .missing
            return
        }
        dictation.stop()
        Task {
            for _ in 0..<40 where dictation.isActive {
                try? await Task.sleep(for: .milliseconds(100))
            }
            setup = .missing
        }
    }
}

#if DEBUG
#Preview {
    WriteInMyVoiceRow()
        .padding()
        .background(Palette.surface)
        .previewEnvironment(seeded: false)
}
#endif
