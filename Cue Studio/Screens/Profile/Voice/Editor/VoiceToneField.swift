//
//  VoiceToneField.swift
//  Cue Studio
//

import SwiftUI

/// "How do you talk on camera?" (Essentials 4): up to two tones, each with a line that sounds like it, then how they come across: energy,
/// sentences, words, humor and swearing. The same field in the guided questions and in the editor.
struct VoiceToneField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            tones
            style
        }
    }

    // MARK: - The tones

    private var tones: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
                ForEach(VoiceSound.allCases) { sound in
                    let picked = current.isChosen(.tone) && current.sounds.contains(sound)
                    VoiceChoiceRow(
                        title: sound.label, detail: sound.example,
                        tag: current.role?.commonSounds.contains(sound) == true
                            ? String(localized: "Common for \(current.role?.label.lowercased() ?? "")") : nil,
                        isOn: picked, isCheck: true, isDimmed: current.sounds.count >= VoiceLimits.tones && current.isChosen(.tone),
                        identifier: "voiceSetup.tone.\(sound.id)"
                    ) {
                        if case .limit = profile.answer(.tone, with: VoiceOption(id: sound.rawValue, label: sound.label)) {
                            toast.show(String(localized: "Max \(VoiceLimits.tones) · tap to remove"))
                        }
                    }
                }
            }
            Text(current.isChosen(.tone) && current.sounds.count >= VoiceLimits.tones
                ? "Up to \(VoiceLimits.tones) · \(current.sounds.count) of \(VoiceLimits.tones)" : "Pick up to \(VoiceLimits.tones)")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - How they come across

    private var style: some View {
        VStack(alignment: .leading, spacing: 14) {
            group(String(localized: "Energy")) {
                VoiceSegmentedChoice(
                    values: VoiceEnergy.allCases, selection: current.style.energy, label: \.label,
                    onPick: { answer(.energy, $0.rawValue, $0.label) }, identifier: "voice.energy"
                )
            }
            group(String(localized: "Sentences")) {
                VoiceSegmentedChoice(
                    values: SentenceLength.allCases, selection: current.style.sentences, label: \.label,
                    onPick: { answer(.sentences, $0.rawValue, $0.label) }, identifier: "voice.sentences"
                )
            }
            group(String(localized: "Words")) {
                VoiceSegmentedChoice(
                    values: WordLevel.allCases, selection: current.style.words, label: \.label,
                    onPick: { answer(.words, $0.rawValue, $0.label) }, identifier: "voice.words"
                )
            }
            group(String(localized: "Humor")) {
                VoiceSegmentedChoice(
                    values: HumorLevel.allCases, selection: current.reach.humor, label: \.label,
                    onPick: { answer(.humor, $0.rawValue, $0.label) }, identifier: "voice.humor"
                )
            }
            group(String(localized: "Swearing")) {
                VoiceSegmentedChoice(
                    values: Swearing.allCases, selection: current.style.swearing, label: \.label,
                    onPick: { answer(.swearing, $0.rawValue, $0.label) }, identifier: "voice.swearing"
                )
                Text("Strong swearing and slurs are never written — Apple Intelligence won’t generate them.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(title)
            content()
        }
    }

    private func answer(_ question: VoiceQuestion, _ id: String, _ label: String) {
        profile.answer(question, with: VoiceOption(id: id, label: label))
    }
}
