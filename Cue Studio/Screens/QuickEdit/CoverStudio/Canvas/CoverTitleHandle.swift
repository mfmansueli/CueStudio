//
//  CoverTitleHandle.swift
//  Cue Studio
//

import SwiftUI

/// The title on Cover Studio's canvas: a tap picks it, one finger moves it (sticking to the middle and the thirds), two
/// fingers resize it, and when picked its frame shows with a handle on the side to make the block wider or narrower. VoiceOver
/// moves it up and down with swipes and reads where it is.
struct CoverTitleHandle: View {
    let viewModel: CoverStudioViewModel
    let size: CGSize

    @State private var moveBase: OverlayPoint?
    @State private var sizeBase: Double?
    @State private var widthBase: Double?

    var body: some View {
        if let frame = viewModel.titleFrame(in: size) {
            let isSelected = viewModel.selection == .title
            let touch = CoverStudioViewModel.titleTouchFrame(frame)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: touch.width, height: touch.height)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous)
                                .strokeBorder(Palette.acc, lineWidth: 2)
                                .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1)
                                .allowsHitTesting(false)
                        }
                    }
                    .onTapGesture {
                        Haptics.selection()
                        viewModel.selection = .title
                        viewModel.step = .text
                    }
                    .gesture(move)
                    .simultaneousGesture(resize)
                if isSelected { widthHandle(frame) }
            }
            .position(x: frame.midX, y: frame.midY)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Title"))
            .accessibilityValue(Text(viewModel.cover.title))
            .accessibilityHint(Text("Swipe up or down to move it"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAdjustableAction { direction in
                let center = viewModel.composition.title.center
                viewModel.updateTitle { $0.center = OverlayPoint(x: center.x, y: center.y + (direction == .increment ? -0.05 : 0.05)) }
            }
            .accessibilityIdentifier("cover.titleHandle")
        }
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(CoverCanvas.space))
            .onChanged { value in
                if moveBase == nil {
                    viewModel.beginGesture()
                    viewModel.selection = .title
                    moveBase = viewModel.composition.title.center
                }
                if let base = moveBase { viewModel.moveTitle(from: base, by: value.translation, in: size) }
            }
            .onEnded { _ in
                moveBase = nil
                viewModel.endGesture()
            }
    }

    private var resize: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if sizeBase == nil {
                    viewModel.beginGesture()
                    sizeBase = viewModel.composition.title.size
                }
                if let base = sizeBase { viewModel.resizeTitle(from: base, by: Double(value.magnification)) }
            }
            .onEnded { _ in
                sizeBase = nil
                viewModel.endGesture()
            }
    }

    /// A white knob on the block's side: dragging it sideways makes the block wider or narrower (the words fit again).
    private func widthHandle(_ frame: CGRect) -> some View {
        let touch = CoverStudioViewModel.titleTouchFrame(frame)
        let height = touch.height
        let width = touch.width
        return Capsule()
            .fill(Palette.Editor.overlayOutline)
            .frame(width: 8, height: 26)
            .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .offset(x: width - Metrics.hitTarget / 2, y: height / 2 - Metrics.hitTarget / 2)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CoverCanvas.space))
                    .onChanged { value in
                        if widthBase == nil {
                            viewModel.beginGesture()
                            widthBase = viewModel.composition.title.width
                        }
                        // Both sides move: the block stays centered.
                        if let base = widthBase { viewModel.updateTitle { $0.width = base + Double(value.translation.width * 2 / max(1, size.width)) } }
                    }
                    .onEnded { _ in
                        widthBase = nil
                        viewModel.endGesture()
                    }
            )
            .accessibilityLabel(Text("Title width"))
            .accessibilityIdentifier("cover.titleWidth")
    }
}
