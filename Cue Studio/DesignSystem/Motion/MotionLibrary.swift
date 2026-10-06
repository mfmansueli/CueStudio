//
//  MotionLibrary.swift
//  Cue Studio
//

import Foundation

/// The boards' motion, loaded once from the bundle: `clip("1.3_voyage")` is the layers and keyframes of that screen.
nonisolated enum MotionLibrary {
    private struct File: Decodable {
        var keyframes: [String: [MotionFrame]]
        var screens: [String: [String: [MotionAnimation]]]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "screens-motion", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    /// The motion of one board by its file name without `.html`; an empty clip (every layer at rest) if the board isn't in the file.
    static func clip(_ screen: String) -> MotionClip {
        guard let file, let layers = file.screens[screen] else { return MotionClip(name: screen, layers: [:], frames: [:]) }
        return MotionClip(name: screen, layers: layers, frames: file.keyframes)
    }
}
