//
//  GraphicStylePanel.swift
//  Cue Studio
//

import SwiftUI

/// The picked graphic over the video (an arrow, a circle, a tag) in two tabs, as a text is styled (owner, canvas 2 F4,
/// 07/11/2026; it was one long scroll): Style, its words (a tag's, fixed over the tabs), color, size and turn; Motion, the
/// text's ready-made motion and keyframes. On the preview it moves like a text, and its corner handle resizes it.
struct GraphicStylePanel: View {
    let viewModel: QuickEditViewModel
    let text: TextOverlay
    let graphic: TextGraphic

    private var tab: EditorPanelTab { viewModel.panelTab == .motion ? .motion : .style }

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .textStyle, play: .motion(viewModel.overlays)) {
            VStack(spacing: 0) {
                if graphic.kind.hasText { words.padding(.horizontal, 16).padding(.bottom, 4) }
                PanelTabs(tabs: EditorPanelTab.graphic, selection: tab) { viewModel.panelTab = $0 }
            }
        } content: {
            switch tab {
            case .motion: MotionKeyframeControls(viewModel: viewModel)
            default: style
            }
        }
    }

    /// A tag's words.
    private var words: some View {
        TextField(String(localized: "Tag"), text: Binding(
            get: { text.text },
            set: { words in viewModel.overlays.updateText(text.id, key: "graphicText.\(text.id)") { $0.text = String(words.prefix(28)) } }
        ))
        .font(.system(.callout, weight: .semibold))
        .submitLabel(.done)
        .padding(.horizontal, 12)
        .frame(height: Metrics.hitTarget)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        .accessibilityIdentifier("edit.graphic.text")
    }

    @ViewBuilder private var style: some View {
        PanelSwatches(
            label: String(localized: "Color"), colors: OverlayColor.palette, selection: text.color,
            identifier: "edit.graphic.color"
        ) { color in viewModel.overlays.updateText(text.id) { $0.color = color } }
        PanelSlider(
            label: String(localized: "Size"), value: text.size / TextGraphic.baseSize * 100,
            range: CoverItem.scaleRange.lowerBound * 100...CoverItem.scaleRange.upperBound * 100, step: 5, defaultValue: 100,
            format: .percent, identifier: "edit.graphic.size",
            onChange: { value in
                viewModel.overlays.updateText(text.id, key: "graphicSize.\(text.id)") { $0.size = value / 100 * TextGraphic.baseSize }
            }
        )
        PanelSlider(
            label: String(localized: "Turn"), value: graphic.rotation * 180 / .pi, range: -180...180, step: 1, defaultValue: 0,
            bipolar: true, format: .degrees, identifier: "edit.graphic.turn",
            onChange: { viewModel.overlays.setGraphicRotation(text.id, degrees: $0) }
        )
    }
}
