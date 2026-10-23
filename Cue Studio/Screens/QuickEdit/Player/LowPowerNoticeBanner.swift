//
//  LowPowerNoticeBanner.swift
//  Cue Studio
//

import SwiftUI

/// Over the bottom of the preview while Low Power Mode is on (`QuickEditViewModel+LowPower`): what it costs the editor and
/// where to turn it off, on the toast's dark fill, with ✕. It never stops anything: the edit goes on under it.
struct LowPowerNoticeBanner: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "battery.25percent")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.accText)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Low Power Mode is on")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Editing runs at 60 frames per second and exports take longer. Turn it off in Control Center for smoother editing.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("edit.lowPowerNotice")
            Button(action: viewModel.dismissLowPowerNotice) {
                Image(systemName: "xmark")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, -10)
            .padding(.trailing, -10)
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("edit.lowPowerNotice.close")
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(Palette.Editor.toast, in: RoundedRectangle(cornerRadius: Metrics.editorNoticeRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
