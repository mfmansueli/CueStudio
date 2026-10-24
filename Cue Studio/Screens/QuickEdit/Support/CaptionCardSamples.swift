//
//  CaptionCardSamples.swift
//  Cue Studio
//

import CoreImage
import Observation
import UIKit

/// The samples Caption style's cards show, drawn by the export's own renderer (`CaptionCollectionRenderer`) off the main
/// thread and kept by what they draw: the card's combination (a saved style's own, with its changes and motion) and the sample
/// line, the word being said lit and a word marked for emphasis. The picked card also gets its drawings over time, to play.
@MainActor
@Observable
final class CaptionCardSamples {
    /// The design's frame the samples are drawn on (a card shows the caption, not the frame).
    private nonisolated static let frame = CGSize(width: 402, height: 714)
    /// How long each sample word is said, and the rest after the line before it plays again.
    private nonisolated static let wordLength: TimeInterval = 0.42
    private nonisolated static let rest: TimeInterval = 0.9

    private(set) var stills: [String: UIImage] = [:]
    private(set) var motions: [String: PresetCardMotion] = [:]
    @ObservationIgnored private var drawn: [String: Int] = [:]
    @ObservationIgnored private var playing: [String: Int] = [:]

    /// Draws what `cards` need with `words`, skipping what is already drawn; the picked card's motion too.
    func prepare(_ cards: [CaptionStyleCard], words: [String]) {
        for card in cards {
            let settings = Self.shown(card.settings)
            var hasher = Hasher()
            hasher.combine(settings)
            hasher.combine(words)
            let key = hasher.finalize()
            if drawn[card.id] != key {
                drawn[card.id] = key
                let id = card.id
                Task.detached(priority: .userInitiated) {
                    let still = Self.still(settings, words: words)
                    await MainActor.run { [weak self] in
                        guard self?.drawn[id] == key else { return }
                        self?.stills[id] = still
                    }
                }
            }
            if card.isSelected, playing[card.id] != key {
                playing[card.id] = key
                let id = card.id
                Task.detached(priority: .utility) {
                    let motion = Self.motion(settings, words: words)
                    await MainActor.run { [weak self] in
                        guard self?.playing[id] == key else { return }
                        self?.motions[id] = motion
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    /// The look at its own size and place: the card shows the style, not where the captions sit.
    private nonisolated static func shown(_ settings: CaptionSettings) -> CaptionSettings {
        var shown = settings
        shown.sizeScale = 1
        shown.center = nil
        shown.format = nil
        return shown
    }

    /// The sample line, timed word by word, the third word marked for emphasis.
    private nonisolated static func cue(_ words: [String]) -> CaptionCue {
        var cue = CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: 0.2 + Double(index) * wordLength, end: 0.2 + Double(index + 1) * wordLength - 0.04)
        })
        if words.count > 2 { cue.emphasis = [2] }
        return cue
    }

    /// The line with its second word being said (the highlight shows), as the video draws that moment.
    private nonisolated static func still(_ settings: CaptionSettings, words: [String]) -> UIImage? {
        let cue = cue(words)
        let overlays = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame, animation: settings.spec.animation)
        let moment = words.count > 1 ? 0.2 + wordLength * 1.5 : 0.3
        let state = overlays.first { $0.isVisible(at: moment) } ?? overlays.last
        return state.flatMap(drawing)
    }

    /// Every drawing of the line over its time, and how it comes in.
    private nonisolated static func motion(_ settings: CaptionSettings, words: [String]) -> PresetCardMotion? {
        let cue = cue(words)
        let overlays = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame, animation: settings.spec.animation)
        let frames = overlays.compactMap { overlay -> PresetCardMotion.Frame? in
            guard let start = overlay.span?.start, let image = drawing(overlay) else { return nil }
            return PresetCardMotion.Frame(start: start, image: image)
        }
        guard let first = overlays.first, !frames.isEmpty else { return nil }
        // The card is about a quarter of the frame's width: the rise shrinks with it.
        return PresetCardMotion(
            frames: frames, loop: cue.end + rest, fadeIn: first.fadeIn, popScale: first.popScale, popDuration: first.popDuration,
            rise: first.riseDistance / 4, riseDuration: first.riseDuration
        )
    }

    private nonisolated static func drawing(_ overlay: FrameOverlay) -> UIImage? {
        guard let lazy = overlay.lazyText, let image = OverlayImageCache().image(for: lazy),
              let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
