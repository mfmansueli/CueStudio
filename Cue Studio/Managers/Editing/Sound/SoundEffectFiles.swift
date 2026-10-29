//
//  SoundEffectFiles.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Where every sound effect's file is, the one place that knows: most are recordings shipped in the app's bundle
/// (`sfx-<id>.caf`: objects and instruments from CC0 libraries, put together and leveled offline in `tools/music/`, mono 48 kHz,
/// as loud as the synthesized ones), and the rest are made by `SoundEffectSynth` on the device the first time they're asked for.
/// An effect added to an edit is linked into its media (`EditMediaFiles.link`), so changing a file never changes an edit.
nonisolated enum SoundEffectFiles {
    /// The effect's recording in the bundle, nil for one Cue synthesizes.
    static func bundled(_ effect: SoundEffect) -> URL? {
        Bundle.main.url(forResource: "sfx-\(effect.rawValue)", withExtension: "caf")
    }

    /// The effect's file: its recording, or the synthesized one (made now if it isn't there yet).
    static func file(for effect: SoundEffect) throws -> URL {
        if let url = bundled(effect) { return url }
        return try SoundEffectSynth.file(for: effect)
    }

    /// How long a file plays, read from its header (cheap), nil if it can't be read.
    static func duration(ofFile url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
