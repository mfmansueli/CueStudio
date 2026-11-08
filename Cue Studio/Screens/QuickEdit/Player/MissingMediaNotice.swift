//
//  MissingMediaNotice.swift
//  Cue Studio
//

import SwiftUI

/// Over the bottom of the preview while the edit names photos, videos or sounds that are no longer on this iPhone
/// (`QuickEditViewModel.missingMedia`): what is wrong and, when taking them out leaves a video, Remove. It stays while they are
/// missing (a toast at opening was gone in seconds and hid "Draft restored"); ✕ hides it for this visit, and the review still asks
/// before exporting past them.
struct MissingMediaNotice: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.warnText)
                .accessibilityHidden(true)
            Text(viewModel.canRemoveMissingMedia
                 ? "Some photos, videos or sounds in this edit are no longer on this iPhone."
                 : "A clip in this edit is no longer on this iPhone. Replace it to export.")
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.canRemoveMissingMedia {
                Button("Remove") { viewModel.removeMissingMedia(viewModel.missingMedia) }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("edit.missingMedia.remove")
            }
            Button(action: viewModel.hideMissingMediaNotice) {
                Image(systemName: "xmark")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -10)
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("edit.missingMedia.close")
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .toastSurface(in: RoundedRectangle(cornerRadius: Metrics.editorNoticeRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.missingMedia")
    }
}
