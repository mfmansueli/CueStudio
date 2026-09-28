//
//  TimelineZoomController.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The Trim timeline's zoom and scroll (see `TimelineZoom` for when it zooms). A change of zoom
/// glides for a moment around an anchor, a moment of the strip that stays under the eye (the edge
/// being dragged, the middle of the red range, the playhead), and the frames, handles and playhead
/// all follow the same numbers on the way. Only the drawing changes: every time stays real.
@MainActor
@Observable
final class TimelineZoomController {
    /// How long a change of zoom glides.
    static let glideDuration: Duration = .milliseconds(280)

    private(set) var zoom: CGFloat = 1
    /// Points the strip is scrolled (`TimelineLayout.offset`).
    private(set) var offset: CGFloat = 0
    /// Where the zoom is headed: `zoom` once a glide is over.
    private(set) var targetZoom: CGFloat = 1
    /// The creator pinched (or used Zoom in / Zoom out): the automatic zoom leaves it alone until
    /// the next "Remove part".
    private(set) var isManual = false
    /// Frames per second of the take, for the deepest zoom and the frame marks.
    private(set) var frameRate: Double = 30
    /// Points per second at zoom 1, from the strip's width and what it shows.
    private(set) var fitPointsPerSecond: CGFloat = 0

    @ObservationIgnored private var glideTask: Task<Void, Never>?

    /// The deepest zoom: frame by frame.
    var maximum: CGFloat {
        TimelineZoom.maximum(fitPointsPerSecond: fitPointsPerSecond, frameRate: frameRate)
    }

    var isZoomed: Bool { zoom > 1.01 }

    /// Frames are wide enough to edit one by one; the strip marks each.
    var isFramePrecise: Bool {
        isZoomed && TimelineZoom.isFramePrecise(pointsPerSecond: fitPointsPerSecond * zoom, frameRate: frameRate)
    }

    /// The line under the Trim buttons while zoomed; nil at zoom 1.
    func hint(isRemovingPart: Bool) -> String? {
        guard isZoomed else { return nil }
        switch (isFramePrecise, isRemovingPart) {
        case (true, true): return String(localized: "Frame by frame · drag the red edges")
        case (false, true): return String(localized: "Zoomed in · drag the red edges")
        case (true, false): return String(localized: "Frame by frame · pinch to zoom out")
        case (false, false): return String(localized: "Zoomed in · pinch to zoom out")
        }
    }

    // MARK: - Setting

    /// What the zoom depends on. A zoom deeper than the new maximum comes back to it.
    func configure(fitPointsPerSecond: CGFloat, frameRate: Double) {
        guard abs(fitPointsPerSecond - self.fitPointsPerSecond) > 0.000_1 || frameRate != self.frameRate else { return }
        self.fitPointsPerSecond = fitPointsPerSecond
        self.frameRate = frameRate
        if fitPointsPerSecond > 0, zoom > maximum { set(zoom: maximum, offset: offset) }
    }

    /// Jumps to a zoom and scroll (a pinch follows the fingers).
    func set(zoom: CGFloat, offset: CGFloat) {
        stopGlide()
        self.zoom = max(1, zoom)
        self.offset = max(0, offset)
        targetZoom = self.zoom
    }

    /// Scrolls without changing the zoom (auto-pan, following the playhead). A glide in progress
    /// stops where it is.
    func pan(to offset: CGFloat) {
        if glideTask != nil {
            stopGlide()
            targetZoom = zoom
        }
        self.offset = max(0, offset)
    }

    /// Goes to `target`, keeping `time` (seconds of the strip) under the eye: it starts at `fromX`
    /// and ends at `toX`. Without `animated` (Reduce Motion) it jumps.
    func glide(
        to target: CGFloat, keeping time: TimeInterval, fromX: CGFloat, toX: CGFloat,
        in layout: TimelineLayout, animated: Bool
    ) {
        stopGlide()
        let destination = max(1, target)
        targetZoom = destination
        guard animated, abs(destination - zoom) > 0.001 || abs(toX - fromX) > 0.5 else {
            zoom = destination
            offset = layout.scrollOffset(placing: time, atX: toX, zoom: destination)
            return
        }
        let start = Double(zoom)
        let end = Double(destination)
        glideTask = Task { [weak self] in
            let clock = ContinuousClock()
            let began = clock.now
            while !Task.isCancelled {
                let progress = min(1, (clock.now - began) / TimelineZoomController.glideDuration)
                let eased = 1 - pow(1 - progress, 3)
                // Evenly in scale, so each step feels the same size.
                let scale = CGFloat(exp(log(start) + (log(end) - log(start)) * eased))
                let x = fromX + (toX - fromX) * CGFloat(eased)
                self?.zoom = scale
                self?.offset = layout.scrollOffset(placing: time, atX: x, zoom: scale)
                if progress >= 1 { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
            if !Task.isCancelled { self?.glideTask = nil }
        }
    }

    /// One step of the ladder in or out, keeping `time` (seconds of the strip) at `x`: VoiceOver's
    /// Zoom in and Zoom out.
    func step(zoomingIn: Bool, keeping time: TimeInterval, atX x: CGFloat, in layout: TimelineLayout, animated: Bool) {
        isManual = true
        let next = TimelineZoom.step(from: targetZoom, zoomingIn: zoomingIn, maximum: maximum)
        glide(to: next, keeping: time, fromX: x, toX: x, in: layout, animated: animated)
    }

    /// A pinch takes over from the automatic zoom.
    func beginPinch() {
        isManual = true
    }

    /// A new "Remove part": the automatic zoom is back.
    func resumeAutomatic() {
        isManual = false
    }

    private func stopGlide() {
        glideTask?.cancel()
        glideTask = nil
    }
}
