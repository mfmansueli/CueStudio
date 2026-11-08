//
//  PersonPlaceLayer.swift
//  Cue Studio
//

import SwiftUI

/// Moving the cut-out creator on the preview, while Background (or the panel of a photo or video shown Behind you) is open and the
/// video is paused: the recording's frame, where the creator now stands, outlined; a drag anywhere moves them, a pinch resizes them,
/// each gesture one undo step. VoiceOver moves and resizes them by actions.
struct PersonPlaceLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    /// Where the creator stood when a finger first took them.
    @State private var gestureStart: PersonPlacement?

    var body: some View {
        if !viewModel.player.isPlaying {
            let placement = viewModel.look.personPlacement
            let box = placement.rect(in: size)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .strokeBorder(Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)
                    .allowsHitTesting(false)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(placeGesture)
                    .accessibilityElement()
                    .accessibilityLabel(Text("You"))
                    .accessibilityValue(Text("Size \(Int((placement.scale * 100).rounded()))%"))
                    .accessibilityHint(Text("Drag to move, pinch to resize, or use the actions"))
                    .accessibilityActions { actions(placement) }
                    .accessibilityIdentifier("edit.personPlaceLayer")
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    // MARK: - Gestures

    /// A drag and a pinch at once, both measured from where the creator stood when the first finger came down.
    private var placeGesture: some Gesture {
        DragGesture(minimumDistance: 2).simultaneously(with: MagnifyGesture())
            .onChanged { value in
                let start = begin()
                let translation = value.first?.translation ?? .zero
                let offset = CGSize(width: translation.width / max(1, size.width), height: translation.height / max(1, size.height))
                viewModel.look.setPersonPlacement(start.moved(by: offset).scaled(by: Double(value.second?.magnification ?? 1)))
            }
            .onEnded { _ in end() }
    }

    @ViewBuilder
    private func actions(_ placement: PersonPlacement) -> some View {
        Button("Move up") { viewModel.look.setPersonPlacement(placement.moved(by: CGSize(width: 0, height: -0.05))) }
        Button("Move down") { viewModel.look.setPersonPlacement(placement.moved(by: CGSize(width: 0, height: 0.05))) }
        Button("Move left") { viewModel.look.setPersonPlacement(placement.moved(by: CGSize(width: -0.05, height: 0))) }
        Button("Move right") { viewModel.look.setPersonPlacement(placement.moved(by: CGSize(width: 0.05, height: 0))) }
        Button("Bigger") { viewModel.look.setPersonPlacement(placement.scaled(by: 1.1)) }
        Button("Smaller") { viewModel.look.setPersonPlacement(placement.scaled(by: 1 / 1.1)) }
    }

    private func begin() -> PersonPlacement {
        if let gestureStart { return gestureStart }
        let start = viewModel.look.personPlacement
        viewModel.player.pause()
        viewModel.beginPanelChange()
        gestureStart = start
        return start
    }

    private func end() {
        guard gestureStart != nil else { return }
        gestureStart = nil
        viewModel.endPanelChange()
    }
}
