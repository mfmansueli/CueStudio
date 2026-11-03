//
//  VoiceInviteSheet.swift
//  Cue Studio
//

import SwiftUI

/// The invitation the first idea sent from the AI card shows while My Cue Voice still has questions open (the owner, 03/11/2026), once
/// (`VoiceQuestionScheduler.invitesBeforeSending`): "Make your scripts sound like you", how much Cue knows (`VoiceMeter`), three glass rows on
/// what the answers give the AI (style, audience, preferences) that come in one after the other as in Ultra AI's invitation, and that the idea
/// waits. **Continue answering** goes on with the questions from where the creator stopped; **Write my script now** sends the idea as it is.
struct VoiceInviteSheet: View {
    let onAnswer: () -> Void
    let onWrite: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CreatorProfileService.self) private var profile
    /// The page has come in: the rows follow it.
    @State private var opened = false
    @State private var pageHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    VoiceMeter(strength: profile.profile.voiceStrength, level: profile.profile.voiceLevel)
                        .padding(.horizontal, 4)
                    VStack(spacing: 10) {
                        benefit("Your style: how you talk, your energy, your words", systemImage: "waveform", order: 0)
                        benefit("Your audience: who watches, and what they already know", systemImage: "person.2", order: 1)
                        benefit("Your preferences: what you talk about and how scripts speak of you", systemImage: "slider.horizontal.3", order: 2)
                    }
                }
                .padding(EdgeInsets(top: 28, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
                .frame(minHeight: pageHeight)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
            footer
        }
        .onAppear { opened = true }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceInvite")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(verbatim: "✦")
                .cueFont(.title, weight: .semibold)
                .foregroundStyle(Palette.aiText)
                .accessibilityHidden(true)
            Text("Make your scripts sound like you")
                .cueFont(.title2, weight: .bold)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("The more Cue knows about you, the closer every script gets to your voice. A few more answers, and the AI writes the way you talk.")
                .cueFont(.body)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// A glass row, as in Ultra AI's invitation: the symbol in a violet disc and the line, coming in one after the other out of a blur.
    private func benefit(_ title: LocalizedStringKey, systemImage: String, order: Int) -> some View {
        let shown = opened || reduceMotion
        let delay = 0.15 + 0.12 * Double(order)
        return HStack(spacing: 14) {
            Image(systemName: systemImage)
                .cueFont(.body, weight: .semibold)
                .foregroundStyle(Palette.aiTextStrong)
                .frame(width: 38, height: 38)
                .background { Circle().fill(Palette.aiFill) }
                .overlay { Circle().strokeBorder(Palette.aiBorder, lineWidth: 0.75) }
                .accessibilityHidden(true)
            Text(title)
                .cueFont(.body, weight: .medium)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.fill) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.75) }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 12)
        .blur(radius: shown ? 0 : 4)
        .animation(reduceMotion ? nil : .smooth(duration: 0.5).delay(delay), value: opened)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text("About a minute. Your idea stays right where it is.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onAnswer()
                dismiss()
            } label: { Text("Continue answering") }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("voiceInvite.answer")
            Button {
                onWrite()
                dismiss()
            } label: { Text("Write my script now") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("voiceInvite.write")
        }
        .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        VoiceInviteSheet(onAnswer: {}, onWrite: {})
    }
    .previewEnvironment(seeded: false)
}
#endif
