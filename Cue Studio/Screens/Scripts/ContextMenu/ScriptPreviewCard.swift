//
//  ScriptPreviewCard.swift
//  Cue Studio
//

import SwiftUI

/// What the creator sees while holding a script: its destination, format and opening lines.
struct ScriptPreviewCard: View {
    let script: Script
    let readSeconds: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ColorDot(color: script.platform.tint)
                Text(script.platform.label).foregroundStyle(Palette.ink)
                Text("·")
                Text("\(script.structure.label) · ~\(DurationText.short(readSeconds))")
            }
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            Text(script.displayTitle)
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Text(script.isEmpty ? String(localized: "Empty script") : CueParser.stripCues(script.text))
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .lineLimit(4)
        }
        .padding(18)
        .frame(width: 340, alignment: .leading)
        .background(Palette.surface)
    }
}

#if DEBUG
#Preview {
    ScriptPreviewCard(script: SampleScripts.morningHabits, readSeconds: 62)
}
#endif
