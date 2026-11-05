//
//  VoicePreviewStrip.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Does it sound like you?": a script written in the creator's voice, shown as it is ("My voice") or as it would be without
/// ("Without", only to compare), with "Sounds like me" and "Adjust". Compact (owner, 05/11/2026): the question and its two answers on
/// one line, the comparison under them in the system's segmented control, the same as Profile › Preview; Record stays the page's one yellow.
struct VoicePreviewStrip: View {
    let showing: VoicePreview.Showing
    /// "Without" is chosen and still being written.
    let isWaiting: Bool
    let onShow: (VoicePreview.Showing) -> Void
    let onApprove: () -> Void
    let onAdjust: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    title
                    Spacer(minLength: 4)
                    answers
                }
                VStack(alignment: .leading, spacing: 6) {
                    title
                    answers
                }
            }
            Picker(selection: Binding(get: { showing }, set: { onShow($0) })) {
                Text("My voice").tag(VoicePreview.Showing.mine)
                Text("Without").tag(VoicePreview.Showing.without)
            } label: {
                Text("Compare")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("page.voice.picker")
            if showing == .without { note }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 10, trailing: 8))
        .background(Palette.aiFill, in: shape)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .animation(.smooth(duration: 0.25), value: showing)
        .animation(.smooth(duration: 0.25), value: isWaiting)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.voicePreview")
    }

    private var title: some View {
        Text("✦ Does it sound like you?")
            .hudFont()
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Palette.aiText)
            .lineLimit(2)
            .accessibilityLabel(Text("Does it sound like you?"))
            .accessibilityAddTraits(.isHeader)
    }

    private var answers: some View {
        HStack(spacing: 6) {
            Button(action: onAdjust) { Text("Adjust") }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("page.voice.adjust")
            Button(action: onApprove) { Label("Sounds like me", systemImage: "checkmark") }
                .buttonStyle(.cueAI(.compact, expands: false))
                .accessibilityIdentifier("page.voice.approve")
        }
        .fixedSize()
    }

    /// Under "Without": it is there only to compare (and while it is written, that it is being written).
    private var note: some View {
        HStack(spacing: 6) {
            if isWaiting {
                ProgressView().controlSize(.mini).tint(Palette.aiText)
                Text("Writing it without your voice…")
            } else {
                Text("Only to compare · Your script keeps your voice")
            }
        }
        .cueFont(.footnote)
        .foregroundStyle(Palette.inkSoft)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("page.voice.note")
    }
}
