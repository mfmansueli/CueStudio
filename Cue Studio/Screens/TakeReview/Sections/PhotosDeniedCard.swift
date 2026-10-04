//
//  PhotosDeniedCard.swift
//  Cue Studio
//

import SwiftUI

/// Photos said no to the save: what happened, and the way out (6.3). Shown over the review's actions until
/// it is closed or the next save works.
struct PhotosDeniedCard: View {
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(Palette.warnText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Photos is off for Cue")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Allow it to save your video.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(url) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("review.photosDenied.settings")
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
        }
        .padding(.leading, 14)
        .padding(.vertical, 6)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.photosDenied")
    }
}

#if DEBUG
#Preview {
    PhotosDeniedCard {}
        .padding()
        .background(Palette.bg)
}
#endif
