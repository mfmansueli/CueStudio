//
//  BlurPanel.swift
//  Cue Studio
//

import SwiftUI

/// Blur area. First, what to hide: the faces found in the frame (numbered on the preview, a tap on one hides and follows it),
/// every face but the largest, or an area to draw. Then the picked area: what it covers, first (`BlurStatusCard`), then how it
/// hides (Blur, Pixelate, Solid, none of them weak), its shape, strength or the bar's color, a soft edge, when it starts and
/// ends; "Preview" in the header plays it again. ◐ shows the video without what's hidden. The box on the preview is the area
/// itself: drag it, pull its corners (`BlurEditingLayer`).
struct BlurPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let blur = viewModel.blur
        if let picking = blur.picking {
            PanelFrame(viewModel: viewModel, panel: .blur) {
                choosing(picking)
            }
        } else if let region = viewModel.selectedBlur {
            PanelFrame(viewModel: viewModel, panel: .blur, compare: blur.blurCompare, play: PanelPlay(action: blur.review)) {
                BlurStatusCard(viewModel: viewModel, region: region)
            } content: {
                settings(region)
            }
        } else {
            // A photo or video picked while it's open: the way to hide something on it.
            PanelFrame(viewModel: viewModel, panel: .blur) {
                PanelNote(text: String(localized: "Hides a face, a plate or a name"))
                PanelButton(label: String(localized: "Blur area"), systemImage: "eye.slash", isPrimary: true, identifier: "edit.blur.start") {
                    blur.startAdding()
                }
            }
        }
    }

    // MARK: - Choosing

    @ViewBuilder
    private func choosing(_ picking: BlurPicking) -> some View {
        let blur = viewModel.blur
        if picking.isSearching {
            HStack(spacing: 10) {
                ProgressView().tint(Palette.ink2)
                Text("Looking for faces…").font(.system(.subheadline)).foregroundStyle(Palette.ink2)
            }
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("edit.blur.searching")
        } else {
            Text(picking.faces.isEmpty
                ? String(localized: "No faces in this frame. Draw an area over a plate, a name on a screen or anything else.")
                : String(localized: "\(picking.faces.count) faces here. Tap the ones to hide in the video: each gets its own area that follows it."))
                .font(.system(.subheadline))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("edit.blur.facesFound")
        }
        if picking.faces.count > 1 {
            PanelButton(label: String(localized: "All but the largest"), systemImage: "person.2.slash", identifier: "edit.blur.allButLargest") {
                blur.pickAllButLargest()
            }
        }
        PanelButton(
            label: String(localized: "Draw an area"), systemImage: "rectangle.dashed", isPrimary: !picking.isSearching && picking.faces.isEmpty,
            identifier: "edit.blur.draw"
        ) { blur.drawArea() }
        PanelNote(text: String(localized: "For text, plates and screens, Solid hides completely."))
    }

    // MARK: - The picked area

    @ViewBuilder
    private func settings(_ region: BlurRegion) -> some View {
        let blur = viewModel.blur
        PanelTiles(
            options: BlurStyle.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage) }, selection: region.style,
            identifier: "edit.blur.style"
        ) { blur.setStyle($0) }
        PanelNote(text: Self.note(for: region.style))
        PanelSegmented(
            label: String(localized: "Area shape"), options: BlurShape.allCases.map { PanelOption($0, $0.label) }, selection: region.shape,
            identifier: "edit.blur.shape"
        ) { blur.setShape($0) }
        if region.style.hasStrength {
            PanelSlider(
                label: String(localized: "Strength"), value: region.strength * 100, range: 0...100, format: .percent, identifier: "edit.blur.strength",
                onChange: { blur.setStrength($0 / 100) },
                onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
            )
        } else {
            PanelSwatches(label: String(localized: "Color"), colors: OverlayColor.palette, selection: region.color, identifier: "edit.blur.color") { color in
                blur.setColor(color)
            }
        }
        PanelSlider(
            label: String(localized: "Soft edge"), value: region.feather * 100, range: 0...100, format: .percent, identifier: "edit.blur.feather",
            onChange: { blur.setFeather($0 / 100) },
            onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
        )
        if let first = viewModel.edit.editedSpans(of: region, in: viewModel.edit.timeline).first, !viewModel.edit.isOnPhoto(region) {
            PanelStepper(
                label: String(localized: "Starts"), value: DurationText.editor(first.start), identifier: "edit.blur.starts",
                onDecrease: { blur.resizeBar(region.id, instance: first, edge: .start, to: first.start - 0.1) },
                onIncrease: { blur.resizeBar(region.id, instance: first, edge: .start, to: first.start + 0.1) }
            )
            PanelStepper(
                label: String(localized: "Ends"), value: DurationText.editor(first.end), identifier: "edit.blur.ends",
                onDecrease: { blur.resizeBar(region.id, instance: first, edge: .end, to: first.end - 0.1) },
                onIncrease: { blur.resizeBar(region.id, instance: first, edge: .end, to: first.end + 0.1) }
            )
        }
        PanelNote(text: String(localized: "Drag the box in the video to move it, pull a corner to resize it. Where it slipped, drag it back at that moment: that spot is yours, and tracking again keeps it."))
    }

    private static func note(for style: BlurStyle) -> String {
        switch style {
        case .blur: String(localized: "A heavy blur: little of what's under it is left.")
        case .pixelate: String(localized: "Large blocks that move with what they hide.")
        case .solid: String(localized: "Nothing of what's under it is left. Best for text, plates and screens.")
        }
    }
}
