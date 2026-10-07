//
//  MyCueVoiceCard.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · My Cue Voice. Not set up: "Make scripts sound like you." and one yellow button that opens the four questions. Set up:
/// the meter ("VOICE 65% · GOOD START"), one sentence of what Cue knows, the next question (answer it here), and two buttons —
/// **Edit voice** (the full page, 9.3) and **✦ Preview** (a sample in the creator's voice).
struct MyCueVoiceCard: View {
    /// The sheet over this card, if one is up: the question to open on, or none for the first.
    @Binding var setup: ProfileVoiceSetup?
    let onPreview: () -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(VoiceQuestionScheduler.self) private var scheduler
    @Environment(AIStatus.self) private var aiStatus
    @State private var editing: VoiceEditorField?

    private var isSet: Bool { profile.profile.hasMinimumVoice }

    var body: some View {
        Group {
            if isSet { setUpCard } else { newCard }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .profileBlock(glow: RadialGradient(colors: [Palette.aiGlow, .clear], center: .topLeading, startRadius: 0, endRadius: 260))
        .sheet(item: $editing) { VoiceEditorSheet(field: $0) }
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Set up

    private var setUpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoiceMeter(strength: profile.profile.voiceStrength, level: profile.profile.voiceLevel)
            Text(profile.profile.voiceSentence)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("profile.voiceSentence")
            if aiStatus.isAvailable, let next = scheduler.remaining.first {
                nextQuestion(next)
            }
            HStack(spacing: 8) {
                NavigationLink { MyCueVoicePage() } label: {
                    Text("Edit voice")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Palette.fill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.editVoice")
                if aiStatus.isAvailable {
                    Button(action: onPreview) {
                        Text("✦ Preview")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.aiTextStrong)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Palette.aiFill, in: Capsule())
                            .overlay(Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.voicePreview")
                }
            }
        }
    }

    /// The next question in the queue, one line, answered in the editor of its field.
    private func nextQuestion(_ item: VoiceQuestion) -> some View {
        Button { editing = VoiceEditorField(item.field) } label: {
            HStack(spacing: 10) {
                Text(verbatim: "✦").foregroundStyle(Palette.aiText)
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Answer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accText)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Palette.bg.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.voiceNext")
    }
}
