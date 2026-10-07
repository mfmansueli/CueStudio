//
//  StudioAdjustBar.swift
//  Cue Studio
//

import SwiftUI

/// The quick adjustments of Studio's bar: **Size · Line · Margin · Mirror · Remote · Aa**, as the system's glass buttons. Tapping Size, Line or
/// Margin chooses it (one at a time; tapping again lets it go) and its slider (`StudioAdjustSlider`) takes the place of the speed slider under the
/// row, so the bar stays the same size while the creator sets how the text sits for their eyes.
/// Mirror flips the text for a beam-splitter glass, Remote opens Remote Control (its icon is yellow while a controller is connected) and Aa
/// opens Display for the font, colors and background.
struct StudioAdjustBar: View {
    /// The adjustment chosen, if any; the panel that holds the bar shows its slider.
    @Binding var selected: StudioAdjustment?
    /// How far the sheet that holds the bar is out (`SheetReveal`): the chips arrive one after another as it goes from 0 to 1.
    var progress: CGFloat = 1
    let onMore: () -> Void
    let onRemote: () -> Void
    let isRemoteConnected: Bool
    /// What Remote Control is doing, for VoiceOver ("Not connected", "Connected"…).
    let remoteStatus: String

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(StudioAdjustment.allCases.enumerated()), id: \.offset) { index, adjustment in
                chip(adjustment).sheetReveal(progress, from: start(of: index), to: end(of: index))
            }
            let first = StudioAdjustment.allCases.count
            mirrorChip.sheetReveal(progress, from: start(of: first), to: end(of: first))
            remoteChip.sheetReveal(progress, from: start(of: first + 1), to: end(of: first + 1))
            moreChip.sheetReveal(progress, from: start(of: first + 2), to: end(of: first + 2))
        }
    }

    // MARK: - Chips

    /// The chips arrive left to right, after the speed below them.
    private func start(of index: Int) -> CGFloat { 0.42 + 0.06 * CGFloat(index) }
    private func end(of index: Int) -> CGFloat { min(1, 0.78 + 0.045 * CGFloat(index)) }

    private func chip(_ adjustment: StudioAdjustment) -> some View {
        chipButton(isOn: selected == adjustment) {
            selected = selected == adjustment ? nil : adjustment
        } label: {
            VStack(spacing: 3) {
                CueIconView(adjustment.icon, size: 20)
                Text(adjustment.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(Text(adjustment.spokenName))
        .accessibilityAddTraits(selected == adjustment ? .isSelected : [])
        .accessibilityIdentifier("studio.adjust.\(adjustment.rawValue)")
    }

    private var mirrorChip: some View {
        let isOn = session.prompter.isMirrored
        return chipButton(isOn: isOn) {
            session.prompter.isMirrored.toggle()
        } label: {
            VStack(spacing: 3) {
                CueIconView(.mirrorText, size: 20)
                Text("Mirror").font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(Text("Mirror text"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityIdentifier("studio.adjust.mirror")
    }

    private var remoteChip: some View {
        chipButton(isOn: false, action: onRemote) {
            VStack(spacing: 3) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 20)
                Text("Remote").font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isRemoteConnected ? Palette.accText : Palette.ink)
        }
        .accessibilityLabel(Text("Remote Control"))
        .accessibilityValue(Text(remoteStatus))
        .accessibilityIdentifier("prompter.remoteButton")
    }

    private var moreChip: some View {
        chipButton(isOn: false, action: onMore) {
            VStack(spacing: 3) {
                Text("Aa").font(.system(size: 17, weight: .semibold)).frame(height: 20)
                Text("More").font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(Text("Display settings"))
        .accessibilityIdentifier("prompter.displayButton")
    }

    /// One chip: the system's Liquid Glass button, prominent and white when on (a chip is never yellow: yellow is the screen's action).
    @ViewBuilder
    private func chipButton(isOn: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        let content = label()
            .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 40)
        Group {
            if isOn {
                Button(action: action) { content }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.chipOn)
            } else {
                Button(action: action) { content }
                    .buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }
}
