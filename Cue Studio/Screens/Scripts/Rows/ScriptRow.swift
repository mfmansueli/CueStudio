//
//  ScriptRow.swift
//  Cue Studio
//

import SwiftUI

/// A script on the Recent list: its title (with "Continue" on the one edited last), the platform's
/// dot and its pipeline status in mono ("● ● 3 TAKES · READY"), and Studio mode and Record at the end.
struct ScriptRow: View {
    let script: Script
    let status: ScriptStatus
    let isContinue: Bool
    let showsQuickActions: Bool
    let onStudio: () -> Void
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(script.displayTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if isContinue {
                        Text("Continue")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.accInk)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Palette.acc, in: Capsule())
                            .fixedSize()
                    }
                }
                HStack(spacing: 6) {
                    ColorDot(color: script.platform.tint, size: 6)
                    HUDLine(values: status.values, dotColor: status.stage?.tint ?? Palette.accText, tint: status.stage?.tint ?? Palette.accText)
                    if let folder = script.folder {
                        Image(systemName: "folder").font(.caption2).foregroundStyle(Palette.ink2)
                        Text(folder).font(.caption).foregroundStyle(Palette.ink2).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsQuickActions {
                Button(action: onStudio) {
                    Image(systemName: "text.alignleft")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 40))
                .accessibilityLabel(Text("Studio mode"))
                .accessibilityIdentifier("row.studioButton")
                Button(action: onRecord) {
                    Image(systemName: "video.fill")
                }
                .buttonStyle(.cueIcon(.tinted, diameter: 40))
                .accessibilityLabel(Text("Record"))
                .accessibilityIdentifier("row.recordButton")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    List {
        ScriptRow(
            script: SampleScripts.lampReview,
            status: ScriptStatus(takes: [], readSeconds: 28, hasDraft: { _ in false }),
            isContinue: true, showsQuickActions: true, onStudio: {}, onRecord: {}
        )
    }
    .previewEnvironment()
}
#endif
