//
//  VoicePreviewStrip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Does it sound like you?": a script written in the creator's voice, shown as it is ("My Cue
/// Voice") or as it would be without ("Without"), with "Sounds like me" and "Adjust".
struct VoicePreviewStrip: View {
    let showing: VoicePreview.Showing
    let isLoading: Bool
    let onShow: (VoicePreview.Showing) -> Void
    let onApprove: () -> Void
    let onAdjust: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("✦ Does it sound like you?")
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Palette.aiText)
                Spacer(minLength: 0)
                if isLoading { ProgressView().controlSize(.mini) }
            }
            HStack(spacing: 0) {
                segment("My Cue Voice", .mine)
                segment("Without", .without)
            }
            .padding(2)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            HStack(spacing: 8) {
                Button(action: onApprove) { Text("Sounds like me") }
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("page.voice.approve")
                Button(action: onAdjust) { Text("Adjust") }
                    .buttonStyle(.cueAI(.compact, expands: false))
                    .accessibilityIdentifier("page.voice.adjust")
            }
        }
        .padding(12)
        .background(Palette.aiFill, in: shape)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.voicePreview")
    }

    private func segment(_ title: LocalizedStringKey, _ value: VoicePreview.Showing) -> some View {
        Button { onShow(value) } label: {
            Text(title)
                .font(.footnote.weight(showing == value ? .semibold : .regular))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background {
                    if showing == value { RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.segmentOn) }
                }
                .frame(minHeight: Metrics.hitTarget - 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(showing == value ? .isSelected : [])
        .accessibilityIdentifier("page.voice.\(value == .mine ? "mine" : "without")")
    }
}
