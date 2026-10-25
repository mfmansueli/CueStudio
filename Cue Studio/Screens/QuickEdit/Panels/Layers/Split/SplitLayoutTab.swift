//
//  SplitLayoutTab.swift
//  Cue Studio
//

import SwiftUI

/// Where the two contents go: one over the other or side by side, half and half or 60/40 (and which content gets the larger
/// share), swapped, and how the seam looks (none, a line, a blur, a shadow). One layout for the whole video for now, said
/// under it. "Show as" turns the support into a window or a full-screen B-roll and back, keeping everything set on it.
struct SplitLayoutTab: View {
    let viewModel: QuickEditViewModel
    let media: MediaOverlay

    private var overlays: OverlaysViewModel { viewModel.overlays }

    var body: some View {
        let layout = overlays.splitLayout
        VStack(alignment: .leading, spacing: 16) {
            PanelSegmented(
                label: String(localized: "Show as"), options: MediaLayout.offered.map { PanelOption($0, $0.label) },
                selection: media.layout, identifier: "edit.mediaLayout"
            ) { layout in Task { await overlays.setMediaLayout(media.id, layout) } }
            HStack(spacing: 8) {
                ForEach(SplitArrangement.allCases) { arrangement in
                    arrangementCard(arrangement, layout: layout)
                }
            }
            PanelSegmented(
                label: String(localized: "Proportion"), options: SplitRatio.allCases.map { PanelOption($0, $0.label) },
                selection: layout.ratio, identifier: "edit.split.ratio"
            ) { ratio in overlays.changeSplitLayout { $0.ratio = ratio } }
            if layout.ratio == .sixtyForty {
                PanelSegmented(
                    label: String(localized: "Larger"), options: SplitArea.allCases.map { PanelOption($0, $0.label) },
                    selection: layout.larger, identifier: "edit.split.larger"
                ) { area in overlays.changeSplitLayout { $0.larger = area } }
            }
            PanelButton(
                label: layout.arrangement == .stacked ? String(localized: "Swap top and bottom") : String(localized: "Swap sides"),
                systemImage: layout.arrangement == .stacked ? "arrow.up.arrow.down" : "arrow.left.arrow.right",
                identifier: "edit.split.swap"
            ) { overlays.swapSplit() }
            PanelSegmented(
                label: String(localized: "Seam"), options: SplitSeam.allCases.map { PanelOption($0, $0.label) },
                selection: layout.seam, identifier: "edit.split.seam"
            ) { seam in overlays.changeSplitLayout { $0.seam = seam } }
            PanelNote(text: String(localized: "Every split screen in this video uses this layout."))
        }
    }

    private func arrangementCard(_ arrangement: SplitArrangement, layout: SplitLayout) -> some View {
        let isOn = layout.arrangement == arrangement
        var shown = layout
        shown.arrangement = arrangement
        return Button {
            guard !isOn else { return }
            Haptics.selection()
            overlays.changeSplitLayout { $0.arrangement = arrangement }
        } label: {
            HStack(spacing: 10) {
                MediaLayoutDiagram(shape: .split(shown), isOn: isOn)
                Text(arrangement.label)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(arrangement.label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.split.arrangement.\(arrangement.rawValue)")
    }
}
