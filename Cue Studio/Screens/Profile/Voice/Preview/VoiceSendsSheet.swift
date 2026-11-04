//
//  VoiceSendsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "What Cue sends" (My Cue Voice · screen 6): the voice exactly as Apple Intelligence reads it, in mono, with how much of the 1200 characters it takes, and
/// whether there is room for the idea. The text is the one that is sent (the same code builds and measures it); when the voice is long Cue trims the
/// examples first, then the tags, then where they post. **Answer the 4 questions again** goes over the guided questions.
struct VoiceSendsSheet: View {
    let onAnswerAgain: () -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(UltraScriptService.self) private var ultra
    @Environment(ScriptStarter.self) private var starter
    @Environment(\.dismiss) private var dismiss

    /// The next script's catchphrases, as it will carry them (`CatchphraseRotation`).
    private var brief: VoiceBrief { ScriptPromptBuilder.brief(for: profile.profile, phrases: profile.nextCatchphrases) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Apple Intelligence").uppercased())
                            .monoFont(size: 10.5, weight: .bold)
                            .interfaceTracking(1)
                            .foregroundStyle(Palette.aiText)
                        Text("What Cue sends")
                            .cueFont(.title2, weight: .bold)
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(AIDisclosure.privateCloud)
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                    // The switch off sends nothing: the voice below is what it would send (§11, A6).
                    if !profile.profile.usesVoiceInAI {
                        Text("“Use my voice in drafts” is off: none of this is sent.")
                            .cueFont(.footnote, weight: .semibold)
                            .foregroundStyle(Palette.warnText)
                            .accessibilityIdentifier("voice.sends.off")
                    }
                    Text("On this iPhone").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
                    briefCard(brief.text, identifier: "voice.sends.brief")
                    meter
                    if ScriptAIService.hasPrivateCloudComputeEntitlement {
                        Text("Private Cloud Compute").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
                        briefCard(cloudBrief.text, identifier: "voice.sends.cloudBrief")
                    }
                    Text("Added before every idea you send to Cue (scripts, hooks, replies), with where you post and the format you pick. Never used to train models.")
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 4)
                    // A request carries a topic only when its idea is about it (`IdeaFocus`): the card shows them all.
                    if profile.profile.topicCount > 0 {
                        Text("Your topics go only when your idea is about one of them.")
                            .cueFont(.footnote)
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 4)
                            .accessibilityIdentifier("voice.sends.topics")
                    }
                    // Up to three catchphrases a script, taking turns (the owner's B10; §11, A9).
                    if CatchphraseRotation.rotates(profile.profile.phrases) {
                        Text("Each script gets up to 3 of your phrases, taking turns. These are the next script’s.")
                            .cueFont(.footnote)
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 4)
                            .accessibilityIdentifier("voice.sends.catchphrases")
                    }
                    if ultra.isAvailable { ultraSection }
                    Button {
                        dismiss()
                        onAnswerAgain()
                    } label: { Text("Answer the 4 questions again") }
                        .buttonStyle(.cueSecondary(.large))
                        .accessibilityIdentifier("voice.sends.again")
                }
                .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 32, trailing: Metrics.gutter))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .tint(Palette.acc)
                        .foregroundStyle(Palette.accInk)
                        .accessibilityIdentifier("voice.sends.done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.sends")
    }

    /// AI Scripts Ultra, where it is offered: the three calls to Google's Gemini as they go out, with the dock's idea and choices.
    private var ultraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ultra AI · sent to Anthropic").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
            Text(ultra.consent.isGranted
                ? AIDisclosure.ultraSends
                : String(localized: "Not allowed: nothing goes to Anthropic. If you allow it, this is what a script you pick Ultra AI for sends."))
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
            UltraPayloadView(payload: starter.ultraPreview())
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.sends.ultra")
    }

    private var cloudBrief: VoiceBrief {
        var next = profile.profile.voice
        next.phrases = profile.nextCatchphrases
        next.reach.length = nil
        // Private Cloud Compute gets the whole voice, the proof too (the owner's D1), in its own budget and with its preferences read as defaults.
        return VoiceBriefBuilder.brief(for: next, budget: AIRequestPolicy.cloudVoiceBudget, contextualPreferences: true)
    }

    private func briefCard(_ text: String, identifier: String) -> some View {
        return Text(text.isEmpty ? String(localized: "Nothing yet. Set up the first questions and it shows here.") : text)
            .monoFont(size: 11.5)
            .lineSpacing(3)
            .foregroundStyle(text.isEmpty ? Palette.ink2 : Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(Palette.sheetNight.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .textSelection(.enabled)
            .accessibilityIdentifier(identifier)
    }

    /// "812 / 1200 CHARACTERS · ✓ ROOM FOR YOUR IDEA", the bar under it, and in orange "LONG · CUE TRIMS EXAMPLES FIRST" when the voice is longer than that.
    private var meter: some View {
        let brief = brief
        let isLong = brief.isLong
        let count = isLong ? brief.fullCost : brief.cost
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(count.formatted()) / \(VoiceBrief.budget.formatted()) CHARACTERS")
                    .foregroundStyle(isLong ? Palette.warnText : Palette.ink2)
                Spacer()
                Text(isLong ? "LONG · CUE TRIMS EXAMPLES FIRST" : "✓ ROOM FOR YOUR IDEA")
                    .foregroundStyle(isLong ? Palette.warnText : Palette.successText)
            }
            .monoFont(size: 10.5, weight: .semibold)
            .interfaceTracking(0.5)
            ProgressView(value: min(1, Double(count) / Double(VoiceBrief.budget)))
                .tint(isLong ? Palette.warn : Palette.acc)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voice.sends.meter")
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) { VoiceSendsSheet(onAnswerAgain: {}) }
        .previewEnvironment()
}
#endif
