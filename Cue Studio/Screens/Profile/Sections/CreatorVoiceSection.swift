//
//  CreatorVoiceSection.swift
//  Cue Studio
//

import SwiftUI

/// How the creator sounds, which the AI writes with: sounds, phrases, audience, style and topics, as the sections of a grouped list (the same look as
/// the Settings pages: the sky, a card for each group, a small header over it, the chosen chip white). One profile for every platform, all of it free.
struct CreatorVoiceSection: View {
    let onAddPhrase: () -> Void

    @Environment(CreatorProfileService.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        Section {
            chips(
                VoiceSound.allCases, isOn: { profile.profile.isChosen(.tone) && profile.profile.sounds.contains($0) }, label: \.label,
                identifier: "sound", toggle: { profile.toggleSound($0) }
            )
        } header: {
            CueSectionHeader("How I sound")
        }
        Section {
            phrases
        } header: {
            CueSectionHeader("My phrases")
        }
        // The same choice the voice setup asks as "Who do you talk to?", shown in the same words.
        Section {
            chips(
                Vocabulary.allCases, isOn: { profile.profile.isChosen(.audience) && profile.profile.vocabulary == $0 },
                label: \.audienceLabel, identifier: "audience", toggle: { profile.setVocabulary($0) }
            )
        } header: {
            CueSectionHeader("Who I talk to")
        }
        Section {
            chips(
                VoiceStyle.allCases, isOn: { profile.profile.styles.contains($0) }, label: \.label,
                identifier: "style", toggle: { profile.toggleStyle($0) }
            )
        } header: {
            CueSectionHeader("My style")
        }
        // The ten topics of the first flight, in its words, and any other one the creator already has.
        Section {
            chips(
                topics, isOn: { profile.profile.niches.contains($0) }, label: \.chipLabel, identifier: "niche",
                key: \.label, toggle: { profile.toggleNiche($0) }
            )
        } header: {
            CueSectionHeader("Topics")
        }
    }

    private var topics: [Niche] {
        Niche.allCases.filter { Niche.offered.contains($0) || profile.profile.niches.contains($0) }
    }

    private var phrases: some View {
        FlowLayout(spacing: 8, lineSpacing: 4) {
            ForEach(profile.profile.phrases, id: \.self) { phrase in
                HStack(spacing: 6) {
                    Text("“\(phrase)”").font(.system(size: 13.5, weight: .medium)).foregroundStyle(Palette.ink)
                    Button { profile.removePhrase(phrase) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 18, height: 18)
                            .background(Palette.ink.opacity(0.18), in: Circle())
                            .frame(minWidth: 30, minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(phrase)"))
                }
                .padding(.leading, 12)
                .padding(.trailing, 2)
                .frame(height: Metrics.filterChipHeight)
                .background(Palette.fill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
            }
            Button(action: onAddPhrase) {
                Text("+ Add")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .padding(.horizontal, 13)
                    .frame(height: Metrics.filterChipHeight)
                    .overlay(Capsule().strokeBorder(Palette.ink3, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Add a phrase"))
            .accessibilityIdentifier("profile.addPhraseButton")
        }
        .cardRowBackground()
    }

    /// A row of chips: the chosen one is white with black text, the others the grey of every chip in the app (a chip is never solid yellow).
    private func chips<Option: Hashable>(
        _ options: [Option], isOn: @escaping (Option) -> Bool, label: @escaping (Option) -> String,
        identifier: String, key: ((Option) -> String)? = nil, toggle: @escaping (Option) -> Void
    ) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = isOn(option)
                Button { toggle(option) } label: {
                    Text(label(option))
                        .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.black : Palette.ink)
                        .padding(.horizontal, 13)
                        .frame(height: Metrics.filterChipHeight)
                        .background(selected ? Palette.chipOn : Palette.fill, in: Capsule())
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("profile.\(identifier).\((key ?? label)(option))")
            }
        }
        .cardRowBackground()
    }
}
