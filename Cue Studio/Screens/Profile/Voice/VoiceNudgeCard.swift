//
//  VoiceNudgeCard.swift
//  Cue Studio
//

import SwiftUI

/// One question about the creator at a time, with one-tap answers: the first Personality question still empty. Shown on
/// Scripts and Takes, and at the top of 9.3. "None of these" retires it, "+ Something else" opens its sheet and "Not now"
/// holds it back for three days.
struct VoiceNudgeCard: View {
    let item: VoicePersonalityItem
    /// "+ Something else": the sheet of this question, with the text field.
    let onSomethingElse: () -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(VoiceNudgeService.self) private var nudges
    @Environment(ToastService.self) private var toast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("My Cue Voice", systemImage: "sparkles")
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Palette.aiText)
                Spacer()
                Button("Not now") { nudges.notNow(item) }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .accessibilityIdentifier("voice.nudge.notNow")
            }
            .padding(.bottom, -8)
            Text(item.question)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(choices, id: \.self) { choice in
                    Button { choose(choice) } label: { FilterChip(label: choice, isSelected: false) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("voice.nudge.option")
                }
                Button { profile.decline(item) } label: { FilterChip(label: String(localized: "None of these"), isSelected: false) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voice.nudge.none")
                Button(action: onSomethingElse) { FilterChip(label: String(localized: "+ Something else"), isSelected: false) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voice.nudge.somethingElse")
            }
        }
        .padding(16)
        .background(Palette.aiFill, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.nudge")
    }

    /// The one-tap answers: the question's options (formats are the app's formats, swearing its two settings).
    private var choices: [String] {
        switch item {
        case .formats: [ScriptType.tutorial, .list, .story, .review].map(\.label)
        case .swearing: Swearing.allCases.map(\.label)
        case .phrases: []
        case .openings, .endings: item.options
        }
    }

    private func choose(_ choice: String) {
        Haptics.selection()
        switch item {
        case .formats:
            if let format = ScriptType.allCases.first(where: { $0.label == choice }) { profile.toggle(format: format) }
        case .swearing:
            profile.setSwearing(Swearing.allCases.first { $0.label == choice })
        case .phrases, .openings, .endings:
            if case .limit(let message) = profile.toggle(choice, for: item) { toast.show(message) }
        }
    }
}
