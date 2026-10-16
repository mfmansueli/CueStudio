//
//  CoverDividerHandle.swift
//  Cue Studio
//

import SwiftUI

/// A before/after's divider on the canvas: a knob in the middle of the line, dragged sideways. VoiceOver moves it with swipes.
struct CoverDividerHandle: View {
    let viewModel: CoverStudioViewModel
    let size: CGSize

    @State private var base: Double?

    var body: some View {
        let position = viewModel.composition.activeSplit?.position ?? 0.5
        Capsule()
            .fill(Palette.Editor.overlayOutline)
            .frame(width: 22, height: 56)
            .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.accInk))
            .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 2)
            .frame(width: Metrics.hitTarget, height: 72)
            .contentShape(Rectangle())
            .position(x: CGFloat(position) * size.width, y: size.height * 0.62)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(CoverCanvas.space))
                    .onChanged { value in
                        if base == nil {
                            viewModel.beginGesture()
                            viewModel.selection = .divider
                            base = position
                        }
                        if let base { viewModel.moveDivider(to: base + Double(value.translation.width / max(1, size.width))) }
                    }
                    .onEnded { _ in
                        base = nil
                        viewModel.endGesture()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Divider"))
            .accessibilityValue(Text(position.formatted(.percent.precision(.fractionLength(0)).locale(.interface))))
            .accessibilityAdjustableAction { direction in
                viewModel.moveDivider(to: position + (direction == .increment ? 0.05 : -0.05))
            }
            .accessibilityIdentifier("cover.divider")
    }
}
