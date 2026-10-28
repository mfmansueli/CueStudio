//
//  TextPictureDrawer.swift
//  Cue Studio
//

import Foundation

/// Draws the picture that follows the fingers away from the main thread, one at a time (`OverlayEditingLayer`): a text with
/// an effect is painted anew when a side tab breaks its lines again or a pinch grows it past its sharpness, 20 to 80 ms on an
/// iPhone 15 Pro, so the fingers never wait for it. While one is drawn only the newest request waits, so a fast drag never
/// queues paintings up; each lands as it is done, the last one asked for last.
@MainActor
final class TextPictureDrawer {
    typealias Work = @Sendable () -> TextOverlayRenderer.Drawing?

    private var isDrawing = false
    private var waiting: (work: Work, land: (TextOverlayRenderer.Drawing?) -> Void)?

    /// Draws `work` once the picture being drawn is done (in place of any other waiting), then hands it to `land`.
    func draw(_ work: @escaping Work, then land: @escaping (TextOverlayRenderer.Drawing?) -> Void) {
        waiting = (work, land)
        if !isDrawing { drawNext() }
    }

    /// Forgets the picture waiting: the gesture ended.
    func cancel() {
        waiting = nil
    }

    private func drawNext() {
        guard let next = waiting else {
            isDrawing = false
            return
        }
        waiting = nil
        isDrawing = true
        let work = next.work
        Task {
            let picture = await Task.detached(priority: .userInitiated) { work() }.value
            next.land(picture)
            drawNext()
        }
    }
}
