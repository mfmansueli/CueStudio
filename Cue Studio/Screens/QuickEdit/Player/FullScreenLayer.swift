//
//  FullScreenLayer.swift
//  Cue Studio
//

import SwiftUI

/// Full screen drawn from how far the video has grown out of its card (`FullScreenMorph`): the dark over the editor, the video on
/// its way from the card to the whole screen with its corners squaring, the arrow riding from the card's foot to over the hint and
/// turning, and the hint coming in at the end. `Animatable`, so the spring hands it every in-between value and each frame is drawn
/// from one (as `SheetFrame`). It is always there and draws nothing while the video is in its card (no second picture to play
/// then). Taps and swipes only while the video is full screen; on the way back the editor has them.
struct FullScreenLayer<Swipe: ViewModifier>: View, Animatable {
    let viewModel: QuickEditViewModel
    var morph: FullScreenMorph
    let pictureSize: CGSize
    let swipe: Swipe

    var animatableData: CGFloat {
        get { morph.shown }
        set { morph.shown = newValue }
    }

    var body: some View {
        // Never faded in or out: it comes in exactly over the card and leaves once back on it.
        if morph.shown > 0.001 || viewModel.isFullScreen { layer.transition(.identity) }
    }

    private var layer: some View {
        ZStack {
            Palette.bg
                .opacity(morph.cover)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.toggleFullScreen() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("Exit full screen"))
                .accessibilityIdentifier("edit.exitFullScreen")
            QuickEditPreview(viewModel: viewModel, size: pictureSize, isFullScreen: true)
                .clipShape(RoundedRectangle(cornerRadius: morph.cornerRadius, style: .continuous))
                .scaleEffect(morph.scale)
                .offset(morph.offset)
                .opacity(morph.pictureOpacity)
            hint
                .opacity(morph.hintOpacity)
                .allowsHitTesting(false)
                .padding(.horizontal, Metrics.gutter)
                // Its top stays where one line's is (`FullScreenMorph.hintTop`, under the arrow); a second line grows down.
                .alignmentGuide(.bottom) { $0[.top] + 30 }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 40)
            PreviewFullScreenArrow(viewModel: viewModel, turn: morph.cover)
                .position(morph.arrowCenter)
        }
        .modifier(swipe)
        .allowsHitTesting(viewModel.isFullScreen)
        .ignoresSafeArea()
    }

    /// "Tap video to play · tap outside to exit" on one line, or its two parts on two where one is too short ("Tippe aufs Video zum
    /// Abspielen · daneben zum Beenden" on an SE): never cut (owner, 02/11/2026).
    private var hint: some View {
        let text = String(localized: "Tap video to play · tap outside to exit")
        return ViewThatFits(in: .horizontal) {
            Text(verbatim: text).lineLimit(1)
            Text(verbatim: text.replacingOccurrences(of: " · ", with: "\n"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(.footnote, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 30)
        .background(Palette.Takes.durationBadge, in: Capsule())
    }
}
