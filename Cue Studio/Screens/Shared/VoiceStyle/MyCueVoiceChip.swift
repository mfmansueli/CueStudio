//
//  MyCueVoiceChip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Voice 65%" on the idea card (v29): how much of the creator Cue knows (`CreatorProfile.voiceStrength`), 0% before any answer (the owner's
/// call, 29/10/2026: the number says there is more to give). Short of room it is "✦ Voice", as wide as the chips beside it, so the whole row
/// fits an iPhone 15 Pro (the owner, 30/10/2026); VoiceOver still says the percentage. Tapping it opens the voice questions from where the
/// creator stopped; once the five are answered, Profile › My Cue Voice, where the answers are looked at and changed (the owner, 03/11/2026).
/// Violet because it is the AI's.
///
/// The card owns `setup` and presents the sheet itself: the card's content is always dark, and a sheet shown from in
/// there would not follow the screen. The card also knows when the setup covers it: the microphone is let go and its
/// light stops moving.
struct MyCueVoiceChip: View {
    @Binding var setup: VoiceSetupSheet.Mode?
    /// The bare first-visit card draws smaller chips (28 pt).
    var isCompact = false
    /// The chip's touch height (the dock's row is 36 pt).
    var hitHeight = Metrics.hitTarget
    /// The dock's row is short of room: "✦ Voice" for "✦ My Cue Voice 65%", and "Voice OFF" for "Neutral voice OFF", 2 pt narrower on each side.
    var isShort = false

    @Environment(CreatorProfileService.self) private var profile
    @Environment(DictationService.self) private var dictation
    @Environment(PresentationService.self) private var presentation
    /// The setup asked for while a dictation was still finishing its last words.
    @State private var pendingSetup: VoiceSetupSheet.Mode?

    private var isSet: Bool { profile.profile.hasMinimumVoice }

    /// The dock's chip (03 · 3.2): "✦ Voice 65%"; "✦ My Cue Voice 0%" before there is enough to use ("✦ Voice" short of room); grey
    /// "Neutral voice · OFF" when the creator turned the voice off.
    private var chip: IdeaCardChip {
        if isSet, !profile.profile.usesVoiceInAI {
            return IdeaCardChip(
                label: isShort ? String(localized: "Voice") : String(localized: "Neutral voice"), style: .off, trailingValue: String(localized: "OFF"),
                hitHeight: hitHeight, isTight: isShort
            )
        }
        if isSet {
            return IdeaCardChip(
                label: String(localized: "Voice"), style: .ai, glyph: "✦", trailingValue: strength,
                isCompact: isCompact, hitHeight: hitHeight, isTight: isShort
            )
        }
        return IdeaCardChip(
            label: isShort ? String(localized: "Voice") : String(localized: "My Cue Voice"), style: .ai, glyph: "✦",
            trailingValue: strength, isCompact: isCompact, hitHeight: hitHeight, isTight: isShort
        )
    }

    /// "65%", where the row has room for it.
    private var strength: String? {
        isShort ? nil : "\(profile.profile.voiceStrength)%"
    }

    var body: some View {
        Button(action: openQuestions) {
            chip
        }
        .buttonStyle(.cuePress)
        .accessibilityLabel(Text("My Cue Voice"))
        .accessibilityValue(Text(verbatim: "\(profile.profile.voiceStrength)%"))
        .accessibilityHint(Text(
            profile.profile.answeredEverySetupStep ? "Opens My Cue Voice to change your answers." : "Answer a few questions so scripts sound like you."
        ))
        .accessibilityIdentifier("ideaCard.voiceChip")
        // The dictation wrote its last words (or let go): the setup asked for meanwhile opens now.
        .onChange(of: dictation.isActive) { _, isActive in
            guard !isActive, let pending = pendingSetup else { return }
            pendingSetup = nil
            setup = pending
        }
    }

    /// Tapping the chip: the questions still open, from where the creator stopped; all answered, My Cue Voice on Profile.
    private func openQuestions() {
        if profile.profile.answeredEverySetupStep {
            if dictation.isActive { dictation.stop() }
            presentation.selectedTab = .profile
            presentation.profilePath = [.myCueVoice]
            return
        }
        let mode = VoiceSetupSheet.Mode.missing
        if dictation.isActive {
            // The dictation writes its last words first; the setup opens when it is done.
            pendingSetup = mode
            dictation.stop()
        } else {
            setup = mode
        }
    }
}
