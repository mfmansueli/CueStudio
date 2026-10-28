//
//  TextEffectCardSamples.swift
//  Cue Studio
//

import Observation
import UIKit

/// The samples Text style's effect cards show: the creator's own first words in each effect, drawn by the export's own
/// renderer (`TextOverlayRenderer`) off the main thread, at rest. The picked card also gets the effect's way in drawn over
/// time, to play (never with Reduce Motion: `PanelPresetCard` shows the still). Kept per card, redrawn only when the words
/// change: six stills and one motion at most.
@MainActor
@Observable
final class TextEffectCardSamples {
    /// The design's frame the samples are drawn on, one and a half pixels per point (a card is about a quarter of it).
    private nonisolated static let frameWidth = TextOverlayRenderer.referenceWidth * 1.5
    /// The motion's drawings per second, and the rest after the way in before it plays again.
    private nonisolated static let framesPerSecond = 15.0
    private nonisolated static let hold: TimeInterval = 1.1
    /// A card shows a few words: never more letters than this, never half a word.
    private nonisolated static let longestSample = 16

    private(set) var stills: [TypePreset: UIImage] = [:]
    private(set) var motions: [TypePreset: PresetCardMotion] = [:]
    @ObservationIgnored private var drawn: [TypePreset: String] = [:]
    @ObservationIgnored private var playing: (preset: TypePreset, words: String)?

    /// The creator's first words, or the cards' own two when the text has none yet.
    static func sample(of text: TextOverlay, fallback: String) -> String {
        var picked: [Substring] = []
        var letters = 0
        for word in text.text.split(whereSeparator: \.isWhitespace) {
            guard picked.isEmpty || letters + word.count <= longestSample else { break }
            picked.append(word)
            letters += word.count + 1
        }
        return picked.isEmpty ? fallback : picked.joined(separator: " ")
    }

    /// Draws what the effect cards need with `words`, skipping what is drawn; the picked card's way in too, when `plays`.
    func prepare(words: String, picked: TypePreset?, plays: Bool) {
        for preset in TypePreset.effectPresets where drawn[preset] != words {
            drawn[preset] = words
            Task.detached(priority: .userInitiated) {
                let still = Self.drawing(preset, words: words, at: nil)
                await MainActor.run { [weak self] in
                    guard self?.drawn[preset] == words else { return }
                    self?.stills[preset] = still
                }
            }
        }
        guard plays, let picked, picked.effect != nil else {
            playing = nil
            motions = [:]
            return
        }
        guard playing?.preset != picked || playing?.words != words else { return }
        playing = (picked, words)
        motions = [:]
        Task.detached(priority: .utility) {
            let motion = Self.motion(picked, words: words)
            await MainActor.run { [weak self] in
                guard self?.playing?.preset == picked, self?.playing?.words == words else { return }
                self?.motions = motion.map { [picked: $0] } ?? [:]
            }
        }
    }

    // MARK: - Drawing

    /// The sample as a title in `preset`, as the video shows it `time` seconds in (at rest without one).
    private nonisolated static func drawing(_ preset: TypePreset, words: String, at time: TimeInterval?) -> UIImage? {
        var text = TextOverlay(role: .title, look: preset.look(for: .title), preset: preset, span: TimeSpan(start: 0, end: 10))
        text.text = words
        return TextOverlayRenderer.drawing(for: text, frameWidth: frameWidth, time: time, length: 10)?.image
    }

    /// The way in drawn over time, then the still while it rests.
    private nonisolated static func motion(_ preset: TypePreset, words: String) -> PresetCardMotion? {
        guard let kind = preset.effect else { return nil }
        let entrance = TextEffect(kind).duration
        let count = Int((entrance * framesPerSecond).rounded(.up)) + 1
        let frames = (0...count).compactMap { index -> PresetCardMotion.Frame? in
            let time = Double(index) / framesPerSecond
            return drawing(preset, words: words, at: time).map { PresetCardMotion.Frame(start: time, image: $0) }
        }
        guard !frames.isEmpty else { return nil }
        return PresetCardMotion(frames: frames, loop: Double(count) / framesPerSecond + hold)
    }
}
