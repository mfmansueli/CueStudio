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
    @Environment(\.dismiss) private var dismiss

    private var brief: VoiceBrief { ScriptPromptBuilder.brief(for: profile.profile) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Apple Intelligence · on this iPhone").uppercased())
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Palette.aiText)
                        Text("What Cue sends")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.56)
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                    }
                    briefCard
                    meter
                    Text("Added before every idea you send to Cue — scripts, hooks, replies, with where you post and the format you pick. Never used to train models.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 4)
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

    private var briefCard: some View {
        let text = brief.text
        return Text(text.isEmpty ? String(localized: "Nothing yet. Set up the first questions and it shows here.") : text)
            .font(.system(size: 11.5, design: .monospaced))
            .lineSpacing(3)
            .foregroundStyle(text.isEmpty ? Palette.inkHint : Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(Palette.sheetNight.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .textSelection(.enabled)
            .accessibilityIdentifier("voice.sends.brief")
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
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .tracking(0.5)
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
