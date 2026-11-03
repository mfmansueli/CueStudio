//
//  ScriptKeystrokeClock.swift
//  Cue Studio
//

import os
import UIKit

/// How long a letter typed takes to reach the screen: from the key (`keyPressed()`) to the next frame the main thread gets to draw, an
/// interval (`studio.cue` / Typing / Keystroke) that holds everything the letter made the app do (the editor, the page's update, the
/// layout). One frame is fluid; more is the lag the owner felt (03/11/2026). The display link runs only while a letter is on its way.
@MainActor
final class ScriptKeystrokeClock: NSObject {
    private static let signposter = OSSignposter(subsystem: "studio.cue", category: "Typing")
    private var link: CADisplayLink?
    private var open: OSSignpostIntervalState?

    func keyPressed() {
        guard open == nil else { return }
        open = Self.signposter.beginInterval("Keystroke", id: Self.signposter.makeSignpostID())
        if link == nil {
            let link = CADisplayLink(target: self, selector: #selector(frame))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        link?.isPaused = false
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func frame() {
        link?.isPaused = true
        guard let open else { return }
        Self.signposter.endInterval("Keystroke", open)
        self.open = nil
    }
}
