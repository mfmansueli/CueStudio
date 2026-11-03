//
//  VoiceSpeechField.swift
//  Cue Studio
//

import SwiftUI

/// "How should scripts talk about you?" (My Cue Voice, right after the kind of creator; the owner, 03/11/2026: the kind of creator carried five
/// questions on one screen): "Scripts say I / We", how the words about them agree and how viewers are addressed (`VoiceAgreementField`), and a
/// short credential for the kinds whose word carries one. Each question under its own title (`VoiceFieldSection`). The guided questions show it as its
/// own step; the editor shows it under the kind of creator.
struct VoiceSpeechField: View {
    @Environment(CreatorProfileService.self) private var profile

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.questionGap) {
            VoiceFieldSection(String(localized: "Scripts say"), help: String(localized: "“We” for a business, a brand or a team.")) {
                VoiceSegmentedChoice(
                    values: SpeaksAs.allCases, selection: current.resolvedSpeaksAs, label: \.label,
                    onPick: { profile.setSpeaksAs($0) }, identifier: "voice.speaksAs"
                )
            }
            VoiceAgreementField()
            if showsCredential { credential }
        }
    }

    /// A short credential, for the kinds of creator whose word carries one ("Registered nurse"). Optional.
    private var showsCredential: Bool {
        current.customRole != nil || current.role == .expert || current.role == .educator
    }

    private var credential: some View {
        VoiceFieldSection(
            String(localized: "Your credential"), detail: String(localized: "optional"),
            help: String(localized: "Cue says it only where it is true of you, and never invents another.")
        ) {
            VoiceTypedField(
                placeholder: String(localized: "e.g. Registered nurse"),
                submit: { text, _ in profile.setCredential(text) }, addLabel: String(localized: "Save"),
                initialText: current.credential ?? "", clearsWhenAdded: false, identifier: "voice.credential"
            )
        }
    }
}
