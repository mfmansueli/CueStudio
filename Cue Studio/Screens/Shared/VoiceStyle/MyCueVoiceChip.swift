//
//  MyCueVoiceChip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ My Cue Voice · Set up" on the idea card. Without enough in the profile, tapping it opens the
/// questions from the first one. Once the voice is set up the chip keeps its name (tapping it opens
/// the questions again, filled in, to edit them) and gets a switch of its own for "write in my
/// voice" (the same state as Profile's).
///
/// The card owns `setup` and presents the sheet itself: the chip sits in the card's always-dark
/// content, and a sheet shown from in there would be dark in the light appearance too. The card also
/// knows when the setup covers it: the microphone is let go and its light stops moving.
struct MyCueVoiceChip: View {
    @Binding var setup: VoiceSetupSheet.Mode?

    @Environment(CreatorProfileService.self) private var profile
    @Environment(DictationService.self) private var dictation
    /// The setup asked for while a dictation was still finishing its last words.
    @State private var pendingSetup: VoiceSetupSheet.Mode?

    private var isSet: Bool { profile.profile.hasMinimumVoice }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: openQuestions) {
                if isSet {
                    IdeaCardChip(label: String(localized: "My Cue Voice"), style: .ai, systemImage: "sparkles", fillsCapsule: false)
                } else {
                    IdeaCardChip(label: String(localized: "My Cue Voice · Set up"), style: .ai, systemImage: "sparkles")
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("My Cue Voice"))
            .accessibilityValue(Text(isSet ? (profile.writesInMyVoice ? "On" : "Off") : "Set up"))
            .accessibilityHint(Text(isSet ? "Opens your voice questions to change them." : "Answer a few questions so scripts sound like you."))
            .accessibilityIdentifier("ideaCard.voiceChip")
            if isSet {
                voiceSwitch
            }
        }
        .background { if isSet { Capsule().fill(Palette.aiFill) } }
        .overlay { if isSet { Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5).frame(height: 32) } }
        // The dictation wrote its last words (or let go): the setup asked for meanwhile opens now.
        .onChange(of: dictation.isActive) { _, isActive in
            guard !isActive, let pending = pendingSetup else { return }
            pendingSetup = nil
            setup = pending
        }
    }

    /// The switch inside the chip: "write in my voice" on or off. Smaller than a settings switch, to fit the chip.
    private var voiceSwitch: some View {
        Toggle(isOn: profile.writesInMyVoiceBinding(needsSetup: { openQuestions() })) {
            Text("Use my voice in AI scripts")
        }
        .labelsHidden()
        .tint(Palette.success)
        .scaleEffect(0.8)
        .frame(width: 44, height: Metrics.hitTarget)
        .padding(.trailing, 4)
        .accessibilityIdentifier("ideaCard.voiceToggle")
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
