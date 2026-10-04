//
//  MyCueVoiceChip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Voice 65%" on the idea card (v29): how much of the creator Cue knows (`CreatorProfile.voiceStrength`); "✦ Voice · Set up"
/// before there is enough for the AI to use. Tapping it opens the voice questions (the full My Cue Voice page, where
/// the voice is switched on and off, is on Profile). Violet because it is the AI's.
///
/// The card owns `setup` and presents the sheet itself: the card's content is always dark, and a sheet shown from in
/// there would not follow the screen. The card also knows when the setup covers it: the microphone is let go and its
/// light stops moving.
struct MyCueVoiceChip: View {
    @Binding var setup: VoiceSetupSheet.Mode?
    /// The bare first-visit card draws smaller chips (28 pt).
    var isCompact = false

    @Environment(CreatorProfileService.self) private var profile
    @Environment(DictationService.self) private var dictation
    /// The setup asked for while a dictation was still finishing its last words.
    @State private var pendingSetup: VoiceSetupSheet.Mode?

    private var isSet: Bool { profile.profile.hasMinimumVoice }

    /// The board's chip: "✦ In your voice 65%"; "✦ My Cue Voice" before there is enough to use; grey "Neutral voice · OFF" when the
    /// creator turned the voice off.
    private var chip: IdeaCardChip {
        if isSet, !profile.profile.usesVoiceInAI {
            return IdeaCardChip(label: String(localized: "Neutral voice"), style: .off, trailingMono: String(localized: "OFF"))
        }
        if isSet {
            return IdeaCardChip(
                label: String(localized: "In your voice"), style: .ai, glyph: "✦", trailingMono: "\(profile.profile.voiceStrength)%", isCompact: isCompact
            )
        }
        return IdeaCardChip(label: String(localized: "My Cue Voice"), style: .ai, glyph: "✦", isCompact: isCompact)
    }

    var body: some View {
        Button(action: openQuestions) {
            chip
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("My Cue Voice"))
        .accessibilityValue(Text(isSet ? "\(profile.profile.voiceStrength)%" : "Set up"))
        .accessibilityHint(Text(isSet ? "Opens your voice questions to change them." : "Answer a few questions so scripts sound like you."))
        .accessibilityIdentifier("ideaCard.voiceChip")
        // The dictation wrote its last words (or let go): the setup asked for meanwhile opens now.
        .onChange(of: dictation.isActive) { _, isActive in
            guard !isActive, let pending = pendingSetup else { return }
            pendingSetup = nil
            setup = pending
        }
    }

    /// Tapping the chip: the questions, from the first one. Set up already, they open filled in.
    private func openQuestions() {
        let mode: VoiceSetupSheet.Mode = isSet ? .edit : .missing
        if dictation.isActive {
            // The dictation writes its last words first; the setup opens when it is done.
            pendingSetup = mode
            dictation.stop()
        } else {
            setup = mode
        }
    }
}
