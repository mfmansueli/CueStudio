//
//  ScriptRow.swift
//  Cue Studio
//

import SwiftUI

struct ScriptRow: View {
    let script: Script
    let readSeconds: TimeInterval
    let showsQuickActions: Bool
    let onStudio: () -> Void
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(script.displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ColorDot(color: script.platform.tint, size: 6)
                    Text(script.platform.label)
                    Text("·")
                    Text(script.structure.label)
                    Text("·")
                    Text("~\(DurationText.short(readSeconds))")
                    if let folder = script.folder {
                        Text("·")
                        Label(folder, systemImage: "folder").labelStyle(.titleAndIcon)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsQuickActions {
                Button(action: onStudio) {
                    Image(systemName: "text.alignleft")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 40))
                .accessibilityLabel(Text("Studio mode"))
                Button(action: onRecord) {
                    Image(systemName: "video.fill")
                }
                .buttonStyle(.cueIcon(.tinted, diameter: 40))
                .accessibilityLabel(Text("Record"))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    List {
        ScriptRow(script: SampleScripts.lampReview, readSeconds: 28, showsQuickActions: true, onStudio: {}, onRecord: {})
    }
    .previewEnvironment()
}
#endif
