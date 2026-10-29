//
//  FullScreenSwipeGesture.swift
//  Cue Studio
//

import SwiftUI

/// The swipe on the preview as a gesture (`FullScreenSwipe`): on the preview's area in the editor (the video and beside it), down
/// to full screen; on the whole screen in full screen, up out of it. While it moves it tells how far the video has followed the
/// finger, and when let go whether it changes the screen and how fast the finger went (`QuickEditView` springs the video on from
/// there). What is laid on the video keeps its own drags: captions, windows and handles have SwiftUI drags that win over this
/// one; a text's gesture never stops another, so once `yields` says something on the video has the drag, the swipe sits the
/// rest of it out.
struct FullScreenSwipeGesture: ViewModifier {
    let isFullScreen: Bool
    let isEnabled: Bool
    /// Something laid on the video has the drag now.
    let yields: () -> Bool
    let moved: (_ follow: CGFloat) -> Void
    let ended: (_ changes: Bool, _ speed: CGFloat) -> Void

    /// Where the drag the swipe sat out began: kept to its end (the text may let go of it first), and a new drag starts
    /// elsewhere, so one that is called off never leaves the swipe stuck.
    @State private var yieldedStart: CGPoint?

    func body(content: Content) -> some View {
        content.gesture(drag, isEnabled: isEnabled)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard yieldedStart != value.startLocation else { return }
                if yields() {
                    // The video goes back to where it rests, in case it had followed the finger a step.
                    yieldedStart = value.startLocation
                    moved(0)
                    return
                }
                moved(FullScreenSwipe(isFullScreen: isFullScreen).follow(value.translation))
            }
            .onEnded { value in
                guard yieldedStart != value.startLocation else {
                    yieldedStart = nil
                    return
                }
                let swipe = FullScreenSwipe(isFullScreen: isFullScreen)
                ended(swipe.changes(value.translation, predicted: value.predictedEndTranslation), swipe.speed(value.velocity))
            }
    }
}
