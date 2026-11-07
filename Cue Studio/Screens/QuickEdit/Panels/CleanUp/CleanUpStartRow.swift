//
//  CleanUpStartRow.swift
//  Cue Studio
//

import SwiftUI

/// Pauses' first row when the take opens on silence: "Starts at “Today…”", how much comes off, Listen (only when tapped) and
/// Trim. When a text or video the creator put there starts in that silence, it says so instead of offering Trim.
struct CleanUpStartRow: View {
    @Bindable var viewModel: QuickEditViewModel
    let proposal: CleanUpStart.Proposal

    var body: some View {
        let clips = viewModel.clips
        let isListening = clips.listeningID == ClipsViewModel.startListenID
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(clips.cleanUpStartTitle(proposal))
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(clips.cleanUpStartDetail(proposal))
                    .cueFont(.caption)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(action: clips.listenToTrimmedStart) {
                Image(systemName: isListening ? "speaker.wave.2.fill" : "headphones")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(isListening ? Palette.accInk : Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(isListening ? Palette.acc : Palette.Slider.track, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Listen to the new start"))
            .accessibilityIdentifier("edit.pauses.start.listen")
            if !proposal.keepsIntro {
                PanelButton(
                    label: clips.cleanUpStartAction(proposal), isCompact: true, identifier: "edit.pauses.start.trim"
                ) { clips.trimToFirstWord() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .editorCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.pauses.start")
    }
}
