//
//  HeroScriptCard.swift
//  Cue Studio
//

import SwiftUI

/// The last edited script, one tap away from the prompter.
struct HeroScriptCard: View {
    let script: Script
    let readSeconds: TimeInterval
    let takeCount: Int
    let onStudio: () -> Void
    let onRecord: () -> Void

    @Environment(PlatformRulesService.self) private var rules

    private var prefersStudio: Bool {
        rules.preset(for: script.platform, monetizationGoals: false).prefersStudio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Last edited")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(Palette.acc)
                Spacer()
                Text(script.updatedAt, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(script.displayTitle)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(script.previewLine.isEmpty ? String(localized: "Empty script") : script.previewLine)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ColorDot(color: script.platform.tint)
                    Text(script.platform.label).foregroundStyle(Palette.ink)
                }
                TagPill(text: script.structure.label)
                Text("~\(DurationText.short(readSeconds)) read")
                Text(takeCount == 0 ? String(localized: "No takes") : String(localized: "\(takeCount) takes"))
            }
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .lineLimit(1)
            HStack(spacing: 10) {
                Button(action: onStudio) {
                    Label("Studio", systemImage: "text.alignleft")
                }
                .buttonStyle(CueStudioButtonStyle(variant: prefersStudio ? .primary : .secondary))
                .accessibilityIdentifier("hero.studioButton")
                Button(action: onRecord) {
                    Label("Record", systemImage: "video.fill")
                }
                .buttonStyle(CueStudioButtonStyle(variant: prefersStudio ? .secondary : .primary))
                .accessibilityIdentifier("hero.recordButton")
            }
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18))
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

#if DEBUG
#Preview {
    HeroScriptCard(script: SampleScripts.morningHabits, readSeconds: 62, takeCount: 3, onStudio: {}, onRecord: {})
        .padding()
        .previewEnvironment()
}
#endif
