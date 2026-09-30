//
//  CaptionAnimator.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A caption line as the overlays its animation shows: the line itself (still or fading), a few
/// words at a time, or one state per word with the word being said standing out. Each overlay is
/// drawn when it shows (`LazyText`). A line whose words don't have their own times from speech
/// recognition shows whole: its words' times would be a guess.
nonisolated enum CaptionAnimator {
    /// Words shown together in Groups.
    static let groupSize = 3
    /// Letters shown together in Groups for languages written without spaces.
    static let unspacedGroupLength = 6

    /// `offset`: where a translation shows next to the original (see `TextOverlay.caption`).
    static func overlays(
        for cue: CaptionCue, look: TextLook, position: CaptionPosition, frame: CGSize, animation: CaptionAnimation, offset: Double = 0
    ) -> [FrameOverlay] {
        let span = cue.span
        guard animation.followsWords, cue.hasWordTiming, cue.words.count > 1 else {
            guard var line = overlay(cue.text, look: look, position: position, span: span, frame: frame, offset: offset) else { return [] }
            if animation == .fade { line.fade = CaptionAnimation.fadeDuration }
            return [line]
        }
        let words = cue.words
        switch animation {
        case .groups:
            let chunks = groups(of: words)
            return chunks.enumerated().compactMap { index, chunk in
                guard let first = chunk.first else { return nil }
                let start = index == 0 ? span.start : first.start
                let end = index + 1 < chunks.count ? (chunks[index + 1].first?.start ?? span.end) : span.end
                guard end > start else { return nil }
                return overlay(
                    CaptionText.joined(chunk.map(\.text)), look: look, position: position,
                    span: TimeSpan(start: start, end: end), frame: frame
                )
            }
        case .highlight, .box:
            let texts = words.map(\.text)
            let line = CaptionText.joined(texts)
            let style: WordEmphasis.Style = animation == .box
                ? .box(fill: .yellow, text: .black)
                : .color(look.color == .yellow ? .white : .yellow)
            // Each word from when it's said to when the next one is; the first from the line's start.
            return words.indices.compactMap { index in
                let start = index == 0 ? span.start : words[index].start
                let end = index + 1 < words.count ? words[index + 1].start : span.end
                guard end > start else { return nil }
                return overlay(
                    line, look: look, position: position, span: TimeSpan(start: start, end: end), frame: frame,
                    emphasis: WordEmphasis(words: texts, index: index, style: style)
                )
            }
        case .line, .fade:
            return []
        }
    }

    /// The line's words in groups: three at a time, or a few letters for languages without
    /// spaces; a sentence's end closes a group.
    static func groups(of words: [CaptionWord]) -> [[CaptionWord]] {
        var result: [[CaptionWord]] = []
        var current: [CaptionWord] = []
        for word in words {
            current.append(word)
            let unspaced = WordSegmenter.containsUnspacedScript(word.text)
            let full = unspaced
                ? CaptionText.length(current.map(\.text)) >= unspacedGroupLength
                : current.count >= groupSize
            let ends = word.text.last.map { ".!?。！？…؟।,".contains($0) } ?? false
            if full || ends {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func overlay(
        _ line: String, look: TextLook, position: CaptionPosition, span: TimeSpan, frame: CGSize,
        emphasis: WordEmphasis? = nil, offset: Double = 0
    ) -> FrameOverlay? {
        let text = TextOverlay.caption(line, look: look, position: position, span: span, offset: offset)
        let fraction = TextOverlayRenderer.captionWidthFraction
        let size = TextOverlayRenderer.size(for: text, frameWidth: frame.width, widthFraction: fraction)
        guard size.width > 0, size.height > 0 else { return nil }
        let center = text.center.clamped
        let x = CGFloat(center.x) * frame.width - size.width / 2
        // Core Image measures y from the bottom.
        let y = frame.height * (1 - CGFloat(center.y)) - size.height / 2
        return FrameOverlay(
            lazyText: LazyText(text: text, emphasis: emphasis, frameWidth: frame.width, widthFraction: fraction),
            size: size, origin: CGPoint(x: x.rounded(), y: y.rounded()), span: span
        )
    }
}
