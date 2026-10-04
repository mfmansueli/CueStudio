//
//  MyCueVoiceChip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ My Cue Voice · Set up" on the idea card. Without enough in the profile it opens the setup;
/// with it, the chip is the switch for "write in my voice" (the same state as Profile's), and says
/// whether it is on.
///
/// The card owns `setup` (which sheet is up), so it knows when the setup covers it: the microphone
/// is let go and its light stops moving while the sheet is open.
struct MyCueVoiceChip: View {
    @Binding var setup: VoiceSetupSheet.Mode?

    @Environment(CreatorProfileService.self) private var profile
    @Environment(DictationService.self) private var dictation
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(ScriptStarter.self) private var starter
    /// The setup asked for while a dictation was still finishing its last words.
    @State private var pendingSetup: VoiceSetupSheet.Mode?

    private var isSet: Bool { profile.profile.hasMinimumVoice }

    private var label: String {
        if !isSet { return String(localized: "My Cue Voice · Set up") }
        return profile.writesInMyVoice ? String(localized: "My Cue Voice · On") : String(localized: "My Cue Voice · Off")
    }

    var body: some View {
        Button(action: tap) {
            IdeaCardChip(label: label, style: .ai, systemImage: "sparkles")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("My Cue Voice"))
        .accessibilityValue(Text(isSet ? (profile.writesInMyVoice ? "On" : "Off") : "Set up"))
        .accessibilityHint(Text(isSet ? "Turns writing in your voice on or off." : "Answer a few questions so scripts sound like you."))
        .accessibilityIdentifier("ideaCard.voiceChip")
        .sheet(item: $setup) { mode in
            // With an idea waiting on the card, the last question writes it: the script is the preview.
            VoiceSetupSheet(mode: mode, profile: profile.profile, ideaText: ideaDraft.submission) { writesScript in
                if writesScript { starter.write() }
            }
        }
        // The dictation wrote its last words (or let go): the setup asked for meanwhile opens now.
        .onChange(of: dictation.isActive) { _, isActive in
            guard !isActive, let pending = pendingSetup else { return }
            pendingSetup = nil
            setup = pending
        }
    }

    private func tap() {
        if isSet {
            profile.setWritesInMyVoice(!profile.writesInMyVoice)
        } else if dictation.isActive {
            // The dictation writes its last words first; the setup opens when it is done.
            pendingSetup = .missing
            dictation.stop()
        } else {
            setup = .missing
        }
    }
}
