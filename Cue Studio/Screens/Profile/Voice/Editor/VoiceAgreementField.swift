//
//  VoiceAgreementField.swift
//  Cue Studio
//

import SwiftUI

/// Under "Scripts say I / We" (the owner's B8, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11.7): how the words about the
/// creator agree ("Write me as", or "Write us as" for a team) and how the viewer is addressed. Both optional. What iOS knows of the person is
/// offered, never chosen for them: the script may be someone else's. Tapping the chosen gender again lets it go (not chosen, never the masculine).
struct VoiceAgreementField: View {
    @Environment(CreatorProfileService.self) private var profile

    private var current: CreatorProfile { profile.profile }
    private var isTeam: Bool { current.resolvedSpeaksAs == .we }
    private var chosen: WordGender? { isTeam ? current.agreement.group : current.agreement.speaker }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            gender
            address
        }
    }

    private var gender: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(isTeam ? String(localized: "Write us as") : String(localized: "Write me as"), detail: String(localized: "optional"))
            VoiceSegmentedChoice(
                values: WordGender.allCases, selection: chosen, label: \.label,
                onPick: { pick in
                    let next = pick == chosen ? nil : pick
                    if isTeam { profile.setGroupGender(next) } else { profile.setSpeakerGender(next) }
                },
                identifier: isTeam ? "voice.groupGender" : "voice.speakerGender"
            )
            if !isTeam, chosen == nil, let suggested = WordGender.fromThisDevice {
                Button {
                    Haptics.selection()
                    profile.setSpeakerGender(suggested)
                } label: {
                    Text("Use “\(suggested.label)” from your iPhone")
                        .cueFont(.subheadline, weight: .semibold)
                        .foregroundStyle(Palette.accText)
                        .frame(minHeight: Metrics.hitTarget, alignment: .leading)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voice.speakerGender.fromDevice")
            }
            Text("In Portuguese, Spanish, French or Italian, words like “tired” change with it. Not chosen, Cue avoids them. It goes with your voice, to Ultra AI too when you pick it.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }

    private var address: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "Speak to viewers"))
            VoiceSegmentedChoice(
                values: AddressForm.allCases, selection: current.agreement.address ?? .informal, label: \.label,
                onPick: { profile.setAddressForm($0) }, identifier: "voice.addressForm"
            )
            Text("Formal suits finance, law, health or business audiences, where the language has it (usted, vous, Sie).")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }
}
