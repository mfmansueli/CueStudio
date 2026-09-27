//
//  DisplayLinkDriver.swift
//  Cue Studio
//

import QuartzCore

/// Calls back once per screen refresh with the time since the previous frame, for smooth scrolling.
/// Call `stop()` when done: the display link retains this object until invalidated.
final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let onFrame: (Double) -> Void

    init(onFrame: @escaping (Double) -> Void) {
        self.onFrame = onFrame
    }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let lastTimestamp else { return }
        // A long gap (app in background, breakpoint) must not jump the text.
        onFrame(min(0.05, link.timestamp - lastTimestamp))
    }
}
