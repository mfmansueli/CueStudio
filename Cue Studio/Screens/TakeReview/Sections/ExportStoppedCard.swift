//
//  ExportStoppedCard.swift
//  Cue Studio
//

import SwiftUI

/// The last export of this take stopped with Cue (closed from the app switcher, or ended by iOS) before it finished. A
/// video file can't go on from the middle, so the way out is to export again, from the start.
struct ExportStoppedCard: View {
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.warnText)
                Text("The last export stopped")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("review.exportStopped.close")
            }
            Text("Cue closed before it finished. Export again to get the video.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button("Save video", action: onSave)
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("review.exportStopped.save")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.exportStopped")
    }
}

#if DEBUG
#Preview {
    ExportStoppedCard(onSave: {}, onClose: {})
        .padding()
        .background(Palette.bg)
}
#endif
