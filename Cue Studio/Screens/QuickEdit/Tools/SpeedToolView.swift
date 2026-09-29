//
//  SpeedToolView.swift
//  Cue Studio
//

import SwiftUI

/// Speed: play and time; the edit's sections (move the playhead to pick one); This section or
/// Whole video; then 0.5× to 2×. The voice keeps its pitch.
struct SpeedToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuickEditTransportBar(viewModel: viewModel)
            LayerTrackView(viewModel: viewModel, bars: [], tint: Palette.acc, identifier: "edit.speedTrack", height: 30)
            if viewModel.hasSections {
                Picker("Applies to", selection: $viewModel.speedScope) {
                    ForEach(SpeedScope.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit.speedScope")
            }
            HStack(spacing: 6) {
                ForEach(PlaybackSpeed.allCases) { speed in
                    let isOn = viewModel.currentSpeed == speed
                    Button { viewModel.setSpeed(speed) } label: {
                        Text(speed.label)
                            .font(.subheadline.weight(isOn ? .bold : .semibold).monospacedDigit())
                            .foregroundStyle(isOn ? Palette.accInk : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: Metrics.chipHeight + 4)
                            .background(isOn ? Palette.acc : Palette.surface2, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("edit.speed.\(speed.rawValue)")
                }
            }
            Text(viewModel.hasSections
                ? viewModel.speedDetail
                : String(localized: "Split in Trim to change the speed of one part"))
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .lineLimit(1)
                .accessibilityIdentifier("edit.speedDetail")
        }
    }
}
