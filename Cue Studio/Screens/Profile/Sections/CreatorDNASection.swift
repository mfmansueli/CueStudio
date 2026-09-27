//
//  CreatorDNASection.swift
//  Cue Studio
//

import SwiftUI

/// Niche, catchphrases and how the creator sounds, which the AI writes with.
struct CreatorDNASection: View {
    let onAddPhrase: () -> Void

    @Environment(CreatorProfileService.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        VStack(alignment: .leading, spacing: 8) {
            label(String(localized: "Niche"))
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Niche.allCases) { niche in
                    let isOn = profile.profile.niches.contains(niche)
                    Button { profile.toggleNiche(niche) } label: {
                        Text(niche.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? Palette.acc : Palette.ink.opacity(0.75))
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(isOn ? Palette.accSoft : Palette.surface2, in: Capsule())
                            .overlay(Capsule().strokeBorder(isOn ? Palette.acc.opacity(0.45) : .clear, lineWidth: 1))
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 6)

        VStack(alignment: .leading, spacing: 8) {
            label(String(localized: "Phrases you always say"))
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(profile.profile.phrases, id: \.self) { phrase in
                    HStack(spacing: 6) {
                        Text("“\(phrase)”").font(.subheadline.weight(.medium))
                        Button { profile.removePhrase(phrase) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .heavy))
                                .frame(width: 18, height: 18)
                                .background(Palette.ink.opacity(0.18), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Remove \(phrase)"))
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 6)
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
        .padding(.vertical, 6)

        VStack(alignment: .leading, spacing: 8) {
            label(String(localized: "How I sound"))
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(VoiceSound.allCases) { sound in
                    let isOn = profile.profile.sounds.contains(sound)
                    Button { profile.toggleSound(sound) } label: {
                        Text(sound.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? Palette.acc : Palette.ink.opacity(0.75))
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(isOn ? Palette.accSoft : Palette.surface2, in: Capsule())
                            .overlay(Capsule().strokeBorder(isOn ? Palette.acc.opacity(0.45) : .clear, lineWidth: 1))
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.ink2)
    }
}
