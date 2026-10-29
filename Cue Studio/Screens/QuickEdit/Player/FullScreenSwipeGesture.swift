//
//  FullScreenSwipeGesture.swift
//  Cue Studio
//

import SwiftUI

/// The swipe on the preview as a gesture (`FullScreenSwipe`): on the preview's area in the editor (the video and beside it), down
/// to full screen; on the whole screen in full screen, up out of it. While it moves it tells how far the video has followed the
/// finger, and when let go whether it changes the screen and how fast the finger went (`QuickEditView` springs the video on from
/// there). What is laid on the video (texts, captions, windows, handles) keeps its own drags.
struct FullScreenSwipeGesture: ViewModifier {
    let isFullScreen: Bool
    let isEnabled: Bool
    let moved: (_ follow: CGFloat) -> Void
    let ended: (_ changes: Bool, _ speed: CGFloat) -> Void

    func body(content: Content) -> some View {
        content.gesture(drag, isEnabled: isEnabled)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                moved(FullScreenSwipe(isFullScreen: isFullScreen).follow(value.translation))
            }
            .onEnded { value in
                let swipe = FullScreenSwipe(isFullScreen: isFullScreen)
                ended(swipe.changes(value.translation, predicted: value.predictedEndTranslation), swipe.speed(value.velocity))
            }
    }
}
