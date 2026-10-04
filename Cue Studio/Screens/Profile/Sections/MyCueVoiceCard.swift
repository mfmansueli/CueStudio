//
//  MyCueVoiceCard.swift
//  Cue Studio
//

import SwiftUI

/// My Cue Voice on Profile. Not set up: "Make scripts sound like you." and one yellow button that
/// opens the four questions. Set up: a live line in the creator's voice, the switch for using it,
/// and "What Cue uses", rows that each open the question that holds them.
struct MyCueVoiceCard: View {
    /// The sheet over this card, if one is up: the question to open on, or none for the first.
    @Binding var setup: ProfileVoiceSetup?

    @Environment(CreatorProfileService.self) private var profile

    private var isSet: Bool { profile.profile.hasMinimumVoice }

    var body: some View {
        Group {
            if isSet { setUpCard } else { newCard }
        }
    }

    // MARK: - Not set up

    private var newCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Make scripts sound like you.")
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Text("4 quick questions — about 20 seconds. No typing needed.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
            Button { setup = ProfileVoiceSetup(mode: .missing) } label: {
                Text("Set up My Cue Voice")
            }
            .buttonStyle(.cuePrimary())
            .padding(.top, 4)
            .accessibilityIdentifier("profile.setUpVoiceButton")
        }
        .padding(.vertical, 6)
    }

    // MARK: - Set up

    private var setUpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sounds like you", systemImage: "sparkles")
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Palette.accText)
                Spacer()
                Text("Live preview")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            Text("“\(profile.profile.voice.sampleLine)”")
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.25), value: profile.profile.voice.sampleLine)
                .accessibilityIdentifier("profile.voiceSample")
            Toggle("Use my voice in AI scripts", isOn: profile.writesInMyVoiceBinding { setup = ProfileVoiceSetup(mode: .missing) })
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.8))
                .tint(Palette.successText)
                .accessibilityIdentifier("profile.useVoiceToggle")
            VStack(alignment: .leading, spacing: 0) {
                Text("What Cue uses")
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Palette.ink2)
                    .padding(.bottom, 4)
                ForEach(VoiceSetupStep.allCases) { step in
                    row(step)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func row(_ step: VoiceSetupStep) -> some View {
        Button { setup = ProfileVoiceSetup(mode: .edit, startAt: step) } label: {
            HStack(spacing: 10) {
                Text(title(step))
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 84, alignment: .leading)
                Text(value(step))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .frame(minHeight: Metrics.hitTarget)
            .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens this question"))
        .accessibilityIdentifier("profile.voiceRow.\(step.rawValue)")
    }

    private func title(_ step: VoiceSetupStep) -> String {
        switch step {
        case .role: String(localized: "I am")
        case .niche: String(localized: "Topics")
        case .audience: String(localized: "Audience")
        case .tone: String(localized: "Voice")
        }
    }

    private func value(_ step: VoiceSetupStep) -> String {
        let current = profile.profile
        switch step {
        case .role: return current.role?.label ?? String(localized: "Not set")
        case .niche: return current.niches.map(\.label).joined(separator: " · ")
        case .audience: return current.vocabulary.audienceLabel
        case .tone: return current.sounds.map(\.label).joined(separator: " · ")
        }
    }
}
