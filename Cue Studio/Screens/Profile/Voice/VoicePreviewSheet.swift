//
//  VoicePreviewSheet.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Preview" on Profile (the board's "Does this sound like you?", 2.5): the same line with **My voice** and **Without** to set side by side, in a card
/// of the app's own, and the switch for using the voice in AI scripts. The line is deterministic, so it changes only when the voice does.
struct VoicePreviewSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @State private var showsVoice = true

    private var voice: CreatorVoice { profile.profile.voice }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "✦ \(String(localized: "Live preview"))")
                    .font(CueStudioFont.hud).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(Palette.aiText)
                Text("Sounds like you")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.56)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Picker("Preview", selection: $showsVoice.animation(.smooth(duration: 0.25))) {
                Text("My voice").tag(true)
                Text("Without").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("profile.voicePreviewMode")
            sample
            Toggle("Use my voice in AI scripts", isOn: profile.writesInMyVoiceBinding { })
                .font(.system(size: 16))
                .foregroundStyle(Palette.ink)
                .tint(Palette.successText)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
                .accessibilityIdentifier("profile.useVoiceToggle")
        }
        .padding(EdgeInsets(top: 12, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
        .accessibilityIdentifier("profile.voicePreviewSheet")
    }

    /// The line in a card: violet-edged with what Cue knows when it is in the creator's voice, plain without.
    private var sample: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: showsVoice ? tag : String(localized: "Without").uppercased())
                .font(CueStudioFont.hud).tracking(1)
                .foregroundStyle(showsVoice ? Palette.aiText : Palette.inkHint)
                .lineLimit(1)
            Text("“\(showsVoice ? voice.sampleLine : voice.plainLine)”")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityIdentifier("profile.voiceSample")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(showsVoice ? Palette.aiFill : Palette.surface, in: shape)
        .overlay(shape.strokeBorder(showsVoice ? Palette.aiBorder : Palette.separator, lineWidth: 0.5))
    }

    /// "✦ CASUAL · CONFIDENT · “HEY FAM”": what the line is made of.
    private var tag: String {
        let summary = voice.summary
        return summary.isEmpty ? "✦" : "✦ \(summary.uppercased())"
    }
}
