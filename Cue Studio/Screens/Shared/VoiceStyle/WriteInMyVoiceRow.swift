//
//  WriteInMyVoiceRow.swift
//  Cue Studio
//

import SwiftUI

/// "Write in my voice" inside the idea card: a quiet row with a switch, and, while it is on, a small
/// way to edit the style. The switch is the same state as Generate's and Profile's
/// (`CreatorProfileService.writesInMyVoice`). Turning it on without enough in the profile opens the
/// short setup instead, and the switch stays off until it is saved.
///
/// The card owns `setup` (which sheet is up), so it knows when the setup covers it: the microphone
/// is let go and its light stops moving while the sheet is open.
struct WriteInMyVoiceRow: View {
    @Binding var setup: VoiceSetupSheet.Mode?

    @Environment(CreatorProfileService.self) private var profile
    @Environment(DictationService.self) private var dictation
    /// The setup asked for while a dictation was still finishing its last words.
    @State private var pendingSetup: VoiceSetupSheet.Mode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: profile.writesInMyVoiceBinding { requestSetup(.missing) }) {
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
            .accessibilityIdentifier("ideaCard.voiceToggle")
            if profile.writesInMyVoice {
                Button { requestSetup(.edit) } label: {
                    Text("Edit style")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ideaCard.editStyleButton")
            }
        }
        .animation(.smooth(duration: 0.2), value: profile.writesInMyVoice)
        .sheet(item: $setup) { mode in
            VoiceSetupSheet(mode: mode, profile: profile.profile)
        }
        // The dictation wrote its last words (or let go): the setup asked for meanwhile opens now.
        .onChange(of: dictation.isActive) { _, isActive in
            guard !isActive, let pending = pendingSetup else { return }
            pendingSetup = nil
            setup = pending
        }
    }

    // MARK: - Actions

    /// Opens the setup, to answer what is missing or to edit it. A dictation still running is
    /// stopped first and gets to write its last words, so the transcription is whole before
    /// another sheet takes the screen; the setup opens when it is done.
    private func requestSetup(_ mode: VoiceSetupSheet.Mode) {
        guard dictation.isActive else {
            setup = mode
            return
        }
        pendingSetup = mode
        dictation.stop()
    }
}

#if DEBUG
#Preview {
    @Previewable @State var setup: VoiceSetupSheet.Mode?
    WriteInMyVoiceRow(setup: $setup)
        .padding()
        .background(Palette.surface)
        .previewEnvironment(seeded: false)
}
#endif
