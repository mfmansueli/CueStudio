//
//  CreatorVoiceSection.swift
//  Cue Studio
//

import SwiftUI

/// How the creator sounds, which the AI writes with: sounds, phrases, vocabulary, style and niche.
/// One profile for every platform, all of it free.
struct CreatorVoiceSection: View {
    let onAddPhrase: () -> Void

    @Environment(CreatorProfileService.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        group(String(localized: "How I sound")) {
            chips(
                VoiceSound.allCases, isOn: { profile.profile.sounds.contains($0) }, label: \.label,
                identifier: "sound", toggle: { profile.toggleSound($0) }
            )
        }
        group(String(localized: "My phrases")) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(profile.profile.phrases, id: \.self) { phrase in
                    HStack(spacing: 6) {
                        Text("“\(phrase)”").font(.subheadline.weight(.medium))
                        Button { profile.removePhrase(phrase) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .heavy))
                                .frame(width: 18, height: 18)
                                .background(Palette.ink.opacity(0.18), in: Circle())
                                .frame(minWidth: 30, minHeight: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Remove \(phrase)"))
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 2)
                    .frame(height: 30)
                    .background(Palette.surface2, in: Capsule())
                }
                Button(action: onAddPhrase) {
                    Text("+ Add")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .overlay(Capsule().strokeBorder(Palette.ink3, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add a phrase"))
                .accessibilityIdentifier("profile.addPhraseButton")
            }
        }
        group(String(localized: "My vocabulary")) {
            Picker("My vocabulary", selection: Binding(get: { profile.profile.vocabulary }, set: { profile.setVocabulary($0) })) {
                ForEach(Vocabulary.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("profile.vocabulary")
        }
        group(String(localized: "My style")) {
            chips(
                VoiceStyle.allCases, isOn: { profile.profile.styles.contains($0) }, label: \.label,
                identifier: "style", toggle: { profile.toggleStyle($0) }
            )
        }
        group(String(localized: "Niche")) {
            chips(
                Niche.allCases, isOn: { profile.profile.niches.contains($0) }, label: \.label,
                identifier: "niche", toggle: { profile.toggleNiche($0) }
            )
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
            content()
        }
        .padding(.vertical, 6)
    }

    private func chips<Option: Hashable>(
        _ options: [Option], isOn: @escaping (Option) -> Bool, label: @escaping (Option) -> String,
        identifier: String, toggle: @escaping (Option) -> Void
    ) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = isOn(option)
                Button { toggle(option) } label: {
                    Text(label(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Palette.accText : Palette.ink.opacity(0.75))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(selected ? Palette.accSoft : Palette.surface2, in: Capsule())
                        .overlay(Capsule().strokeBorder(selected ? Palette.acc.opacity(0.45) : .clear, lineWidth: 1))
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("profile.\(identifier).\(label(option))")
            }
        }
    }
}
