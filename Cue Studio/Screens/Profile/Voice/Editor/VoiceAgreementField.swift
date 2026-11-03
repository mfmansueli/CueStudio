//
//  VoiceAgreementField.swift
//  Cue Studio
//

import SwiftUI

/// Under "Scripts say I / We" (the owner's B8, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11.7): how the words about the
/// creator agree ("Write me as", or "Write us as" for a team) and how the viewer is addressed, each under its own title (`VoiceFieldSection`). Both
/// optional. What iOS knows of the person is
/// offered, never chosen for them: the script may be someone else's. Tapping the chosen gender again lets it go (not chosen, never the masculine).
///
/// Each one is asked where it changes the scripts (the owner's item 8, 02/11/2026): in the script language of Settings › Language & Region (else
/// the app's). Elsewhere it waits under "More questions", always reachable, and one already chosen stays in view.
struct VoiceAgreementField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(LanguageService.self) private var languages

    @State private var showsMore = false

    private var current: CreatorProfile { profile.profile }
    private var isTeam: Bool { current.resolvedSpeaksAs == .we }
    private var chosen: WordGender? { isTeam ? current.agreement.group : current.agreement.speaker }
    private var code: String { (languages.scriptLanguage ?? languages.interfaceLanguage).rawValue }
    private var genderWords: (feminine: String, masculine: String)? { AgreementGuide.genderExample(in: code, team: isTeam) }
    private var yous: (informal: String, formal: String)? { AgreementGuide.addressExample(in: code) }
    private var asksGender: Bool { genderWords != nil || chosen != nil }
    private var asksAddress: Bool { yous != nil || current.agreement.address != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.questionGap) {
            if asksGender { gender }
            if asksAddress { address }
            if !asksGender || !asksAddress { more }
        }
    }

    private var more: some View {
        DisclosureGroup(isExpanded: $showsMore) {
            VStack(alignment: .leading, spacing: Metrics.questionGap) {
                if !asksGender { gender }
                if !asksAddress { address }
            }
            .padding(.top, 12)
        } label: {
            Text("More questions")
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink2)
                .frame(minHeight: Metrics.hitTarget, alignment: .leading)
                // On the label, not the group: a group's identifier would be its questions' too.
                .accessibilityIdentifier("voice.agreement.more")
        }
        .tint(Palette.ink2)
        .padding(.horizontal, 4)
    }

    private var gender: some View {
        VoiceFieldSection(
            isTeam ? String(localized: "Write us as") : String(localized: "Write me as"), detail: String(localized: "optional"), help: genderNote
        ) {
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
        }
    }

    private var genderNote: String {
        guard let words = genderWords else {
            return String(localized: "Only changes scripts in Portuguese, Spanish, French, Italian, Hindi or Arabic.")
        }
        return isTeam
            ? String(localized: "Pick how words about your team are written: “\(words.feminine)” or “\(words.masculine)”.")
            : String(localized: "Pick how words about you are written: “\(words.feminine)” or “\(words.masculine)”.")
    }

    private var address: some View {
        VoiceFieldSection(
            String(localized: "Speak to viewers"),
            help: yous.map { String(localized: "Pick how scripts speak to viewers: “\($0.informal)” or “\($0.formal)”.") }
                ?? String(localized: "Only changes scripts in languages with a formal “you”.")
        ) {
            VoiceSegmentedChoice(
                values: AddressForm.allCases, selection: current.agreement.address ?? .informal, label: \.label,
                onPick: { profile.setAddressForm($0) }, identifier: "voice.addressForm"
            )
        }
    }
}
