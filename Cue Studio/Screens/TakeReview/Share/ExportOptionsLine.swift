//
//  ExportOptionsLine.swift
//  Cue Studio
//

import SwiftUI

/// "Export options · 1080p · captions on ›": the quiet line that opens Export options (`ShareExportOptions`) where the creator saves without
/// going through Ready to travel (D11): under the review's Share, for Save, and under the editor's Done answers. Secondary text (`ink2`), a full
/// hit target, nothing yellow: it is there for whoever needs it.
struct ExportOptionsLine: View {
    /// "1080p · captions on" (`TakeReviewViewModel.outputSummary(for:)`).
    let summary: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3").imageScale(.small)
                Text("Export options · \(summary)")
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.forward").imageScale(.small).accessibilityHidden(true)
            }
            .cueFont(.footnote)
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    ExportOptionsLine(summary: "1080p · captions on", identifier: "preview") {}
        .padding()
        .background(Palette.surface)
}
#endif
