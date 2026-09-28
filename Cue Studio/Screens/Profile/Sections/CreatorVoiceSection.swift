//
//  CreatorVoiceSection.swift
//  Cue Studio
//

import SwiftUI

/// How the creator sounds, which the AI writes with: sounds, phrases, vocabulary, style and niche.
/// One profile for every platform. Vocabulary and style are part of Pro: on the free plan they
/// carry the PRO badge and open the paywall.
struct CreatorVoiceSection: View {
    let onAddPhrase: () -> Void
    let onLocked: () -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(StoreManager.self) private var store

    private var isLocked: Bool { !ProFeature.fullCreatorVoice.isUnlocked(for: store.tier) }

    var body: some View {
        @Bindable var profile = profile
        group(String(localized: "How I sound")) {
            chips(VoiceSound.allCases, isOn: { profile.profile.sounds.contains($0) }, label: \.label, identifier: "sound") {
                profile.toggleSound($0)
            }
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
                        .foregroundStyle(Palette.acc)
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
        group(String(localized: "My vocabulary"), isPro: true) {
            Picker("My vocabulary", selection: Binding(
                get: { profile.profile.vocabulary },
                set: { vocabulary in
                    if isLocked { onLocked() } else { profile.profile.vocabulary = vocabulary }
                }
            )) {
                ForEach(Vocabulary.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .opacity(isLocked ? 0.5 : 1)
            .accessibilityIdentifier("profile.vocabulary")
        }
        group(String(localized: "My style"), isPro: true) {
            chips(VoiceStyle.allCases, isOn: { !isLocked && profile.profile.styles.contains($0) }, label: \.label, identifier: "style") {
                if isLocked { onLocked() } else { profile.toggleStyle($0) }
            }
            .opacity(isLocked ? 0.5 : 1)
        }
        group(String(localized: "Niche")) {
            chips(Niche.allCases, isOn: { profile.profile.niches.contains($0) }, label: \.label, identifier: "niche") {
                profile.toggleNiche($0)
            }
        }
    }

    private func group<Content: View>(_ title: String, isPro: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                if isPro && isLocked { ProBadge() }
            }
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
                        .foregroundStyle(selected ? Palette.acc : Palette.ink.opacity(0.75))
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
