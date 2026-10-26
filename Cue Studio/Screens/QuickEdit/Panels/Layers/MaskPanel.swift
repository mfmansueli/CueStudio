//
//  MaskPanel.swift
//  Cue Studio
//

import SwiftUI

/// Mask, for the picked photo or video over the take (`OverlaysViewModel+Mask`): the shapes (None, Rectangle, Circle, Line,
/// Band), what a drag on the preview moves (the mask, or the picture under it), Soft edge, Corners (a rectangle's) and Invert,
/// each named, not only a handle; in Advanced the turn and the size in steps, for a precise mask on a small screen. ◐ shows
/// the media whole; Reset puts the mask back where its shape starts. The handles on the preview are the mask's real outline
/// (`MaskEditingLayer`).
struct MaskPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        if let media = viewModel.selectedMedia {
            let overlays = viewModel.overlays
            PanelFrame(
                viewModel: viewModel, panel: .mask, onReset: overlays.maskIsAdjusted ? { overlays.resetMask() } : nil, compare: overlays.maskCompare
            ) {
                PanelTiles(options: Self.shapes, selection: media.mask?.shape, identifier: "edit.maskShape") { shape in
                    overlays.setMaskShape(shape)
                }
                if let mask = media.mask, let placement = overlays.maskPlacementAtPlayhead(of: media) {
                    settings(mask, placement: placement, media: media)
                } else {
                    PanelNote(text: String(localized: "Pick a shape: only the part of the photo or video inside it shows, with the video under it around it."))
                }
            }
        }
    }

    private static var shapes: [PanelOption<MaskShape?>] {
        [PanelOption(nil, String(localized: "None"), systemImage: "circle.slash", key: "none")]
            + MaskShape.allCases.map { shape in
                PanelOption(Optional(shape), shape.label, systemImage: symbol(of: shape), key: shape.rawValue)
            }
    }

    private static func symbol(of shape: MaskShape) -> String {
        switch shape {
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .line: "line.diagonal"
        case .band: "equal"
        }
    }

    @ViewBuilder
    private func settings(_ mask: MediaMask, placement: MaskPlacement, media: MediaOverlay) -> some View {
        let overlays = viewModel.overlays
        PanelSegmented(
            label: String(localized: "Drag moves"), options: MaskDragTarget.allCases.map { PanelOption($0, $0.label) },
            selection: overlays.maskDragTarget, identifier: "edit.maskDrag"
        ) { target in overlays.maskDragTarget = target }
        PanelSlider(
            label: String(localized: "Soft edge"), value: placement.feather * 100, range: 0...100, format: .percent, identifier: "edit.maskFeather",
            onChange: { overlays.setMaskFeather($0 / 100) },
            onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
        )
        if mask.shape.hasCorners {
            PanelSlider(
                label: String(localized: "Corners"), value: placement.corners * 100, range: 0...100, format: .percent, identifier: "edit.maskCorners",
                onChange: { overlays.setMaskCorners($0 / 100) },
                onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
            )
        }
        PanelToggleRow(
            label: String(localized: "Invert"), detail: String(localized: "Shows what's outside the shape instead"), isOn: mask.inverted,
            identifier: "edit.maskInvert"
        ) { overlays.setMaskInverted(!mask.inverted) }
        PanelAdvancedButton(isOpen: viewModel.showsAdvanced, identifier: "edit.maskAdvanced") { viewModel.showsAdvanced.toggle() }
        if viewModel.showsAdvanced { precise(mask, placement: placement) }
        if overlays.maskFollowsKeyframes(media) {
            PanelNote(text: String(localized: "It moves by keyframes: a change to the mask is kept on the keyframe at the playhead, so the mask can change over time."))
                .accessibilityIdentifier("edit.maskKeyframesNote")
        }
        PanelNote(text: overlays.maskDragTarget == .mask
            ? String(localized: "Drag the mask on the video to show another part; pinch to resize it, turn with two fingers.")
            : String(localized: "Drag the picture under the mask to reframe it; pinch to bring it closer."))
    }

    /// The turn and the size in steps.
    @ViewBuilder
    private func precise(_ mask: MediaMask, placement: MaskPlacement) -> some View {
        let overlays = viewModel.overlays
        PanelStepper(
            label: String(localized: "Turn"), value: "\(Int(placement.rotation.rounded()))°", identifier: "edit.maskRotation",
            onDecrease: { overlays.setMaskRotation(placement.rotation.rounded() - 1) },
            onIncrease: { overlays.setMaskRotation(placement.rotation.rounded() + 1) }
        )
        if mask.shape != .line {
            let size = mask.shape == .band ? placement.height : max(placement.width, placement.height)
            PanelStepper(
                label: mask.shape == .band ? String(localized: "Thickness") : String(localized: "Size"),
                value: PanelValueFormat.percent.text(size * 100), identifier: "edit.maskSize",
                onDecrease: { overlays.scaleMask(by: 0.95) }, onIncrease: { overlays.scaleMask(by: 1 / 0.95) }
            )
        }
    }
}
