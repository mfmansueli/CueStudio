//
//  CaptionCollectionRenderer+Motion.swift
//  Cue Studio
//

import UIKit

/// Captions with motion (`CaptionMotion`): each line comes in and goes out its way (fade, pop, rise), shows whole or word by
/// word, and lights the word being said its way (color, box, a box sliding from word to word, a pop). Every state is one more
/// drawing of the same layout (`CaptionMarkup`): the box and the pop are drawn over the words, never moving them, and a pop or
/// a slide is two or three short states, so the preview and the export play them alike, frame for frame.
nonisolated extension CaptionCollectionRenderer {
    /// How a popped word lands: a little past its size for an instant, then at it (seconds, scale), after `popScale` holds.
    private static let popSteps: [(length: TimeInterval, scale: Double)] = [(0.045, 1.05), (0.05, 1.17)]
    /// The longest breath after which the sliding box still comes from the word before.
    private static let glideBreath: TimeInterval = 0.3

    static func motionOverlays(
        _ cues: [CaptionCue], settings: CaptionSettings, motion: CaptionMotion, position: CaptionPosition, frame: CGSize
    ) -> [FrameOverlay] {
        // The style's own way in keeps its tuned numbers (a style from before the catalogue: the way its reading came in).
        let styleEntry = (settings.styleSpec.motion ?? CaptionMotion(playing: .line, spec: settings.styleSpec)).entry
        let unit = min(frame.width, frame.height) / TextOverlayRenderer.referenceWidth
        return cues.flatMap { cue -> [FrameOverlay] in
            let settings = styled(settings, for: cue.lineStyle)
            let spec = settings.spec
            // The style's own way in keeps its tuned numbers; another one picked over it plays the usual ones.
            let entry = motion.entry == styleEntry ? spec.entry : motion.entry.drawn
            let words = cue.lineWords
            let marks = cue.shownEmphasis
            guard let placed = placement(cue, settings: settings, position: position, frame: frame) else { return [] }
            func overlay(_ span: TimeSpan, _ markup: CaptionMarkup) -> FrameOverlay {
                var markup = markup
                markup.emphasized = marks
                return FrameOverlay(
                    lazyText: LazyText(text: placed.text, emphasis: nil, frameWidth: frame.width, widthFraction: placed.widthFraction,
                                       collection: settings, frameHeight: frame.height, markup: markup),
                    size: placed.size, origin: placed.origin, span: span
                )
            }
            /// The line coming in and going out across its states, timed from its first and to its last.
            func entered(_ states: [FrameOverlay]) -> [FrameOverlay] {
                guard let comesIn = states.first?.span?.start, let goesOut = states.last?.span?.end else { return states }
                return states.map { state in
                    var state = state
                    state.fadeIn = entry.fade
                    state.popScale = entry.popScale
                    state.popDuration = entry.popDuration
                    state.riseDistance = CGFloat(entry.rise) * unit
                    state.riseDuration = entry.riseDuration
                    state.fadeOut = entry.fade
                    state.entryStart = comesIn
                    state.exitEnd = goesOut
                    return state
                }
            }
            if cue.lineStyle?.isEmphasized == true, !words.isEmpty {
                let lit = CaptionMarkup(lit: 0, litCount: words.count, spoken: motion.spoken.boxes ? .box : .color)
                return entered([overlay(cue.span, lit)])
            }
            guard motion.followsWords, !words.isEmpty else { return entered([overlay(cue.span, CaptionMarkup())]) }
            let reveals = motion.reveal == .words
            var states: [FrameOverlay] = []
            var cursor = cue.start
            // Word by word: nothing shows before the first word is said.
            if reveals, let first = words.first { cursor = max(cue.start, first.start) }
            var previous: Int?
            for index in words.indices {
                let word = words[index]
                let start = max(cursor, word.start, cue.start)
                let end = min(cue.end, word.end, index + 1 < words.count ? words[index + 1].start : cue.end)
                if start > cursor {
                    // A breath between words: the words said so far stay, none is lit. After a short one the sliding box still
                    // comes from the word before.
                    states.append(overlay(TimeSpan(start: cursor, end: start), CaptionMarkup(revealedThrough: reveals ? index - 1 : nil)))
                    if start - cursor >= Self.glideBreath { previous = nil }
                }
                if end > start {
                    let span = TimeSpan(start: start, end: end)
                    states += wordStates(index, span: span, motion: motion, after: previous).map { overlay($0.span, $0.markup) }
                    previous = index
                }
                cursor = max(cursor, end)
            }
            if cursor < cue.end { states.append(overlay(TimeSpan(start: cursor, end: cue.end), CaptionMarkup())) }
            return entered(states.isEmpty ? [overlay(cue.span, CaptionMarkup())] : states)
        }
    }

    /// The states while word `index` is said over `span`: one, or a pop's landing, or the box sliding from the word lit right
    /// before (`after`).
    private static func wordStates(
        _ index: Int, span: TimeSpan, motion: CaptionMotion, after previous: Int?
    ) -> [(span: TimeSpan, markup: CaptionMarkup)] {
        var markup = CaptionMarkup(lit: motion.spoken == .none ? nil : index, spoken: motion.spoken)
        if motion.reveal == .words { markup.revealedThrough = index }
        var steps: [(TimeInterval, CaptionMarkup)] = []
        switch motion.spoken {
        case .pop:
            for step in popSteps {
                var landing = markup
                landing.popScale = step.scale
                steps.append((step.length, landing))
            }
            markup.popScale = CaptionSpokenHighlight.popScale
        case .glide where previous == index - 1 && index > 0:
            for progress in [0.34, 0.67] {
                var sliding = markup
                sliding.glideFrom = index - 1
                sliding.glideProgress = progress
                steps.append((CaptionSpokenHighlight.glideDuration / 3, sliding))
            }
        default:
            break
        }
        // Steps only where the word lasts long enough to land after them.
        let total = steps.reduce(0) { $0 + $1.0 }
        guard !steps.isEmpty, span.duration > total + 0.03 else { return [(span, markup)] }
        var states: [(TimeSpan, CaptionMarkup)] = []
        var cursor = span.start
        for (length, step) in steps {
            states.append((TimeSpan(start: cursor, end: cursor + length), step))
            cursor += length
        }
        states.append((TimeSpan(start: cursor, end: span.end), markup))
        return states
    }

    // MARK: - Drawing

    /// The words of one state with motion: the words not said yet left out, the word being said lit its way, the marked words
    /// as the layout set them. Called inside the image's drawing, after the plate.
    static func drawPlaying(
        _ markup: CaptionMarkup, text: String, display: String, layout: Layout, settings: CaptionSettings, in context: CGContext
    ) {
        let spec = settings.spec
        let storage = layout.storage
        let length = (display as NSString).length
        let all = layout.manager.glyphRange(for: layout.container)
        let words = CaptionText.words(in: text)
        let breaks = CaptionText.breaks(in: text)
        func range(_ index: Int, count: Int = 1) -> NSRange? {
            WordEmphasis(words: words, index: index, style: .reveal, count: count, breaks: breaks).range(in: display, letterCase: spec.letterCase)
        }
        func hide(_ hidden: NSRange) {
            guard hidden.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: UIColor.clear, range: hidden)
            storage.removeAttribute(.shadow, range: hidden)
            storage.removeAttribute(.strokeWidth, range: hidden)
        }
        func boxes(_ characters: NSRange) -> [CGRect] {
            let glyphs = layout.manager.glyphRange(forCharacterRange: characters, actualCharacterRange: nil)
            var rects: [CGRect] = []
            layout.manager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                                 in: layout.container) { rect, _ in
                rects.append(rect.offsetBy(dx: layout.origin.x, dy: layout.origin.y).insetBy(dx: -5 * layout.unit, dy: -1.5 * layout.unit))
            }
            return rects
        }
        if let through = markup.revealedThrough {
            if through < 0 {
                hide(NSRange(location: 0, length: length))
            } else if let said = range(through) {
                hide(NSRange(location: said.location + said.length, length: length - said.location - said.length))
            }
        }
        var popped: NSRange?
        if let lit = markup.lit, let litRange = range(lit, count: markup.litCount) {
            let accent = settings.highlightColor
            switch markup.spoken {
            case .none:
                break
            case .color:
                storage.addAttribute(.foregroundColor, value: color(accent), range: litRange)
            case .box, .glide:
                var rects = boxes(litRange)
                if markup.spoken == .glide, let from = markup.glideFrom, let source = range(from).flatMap({ boxes($0).first }),
                   let target = rects.first, abs(source.midY - target.midY) < 1 {
                    let progress = CGFloat(min(max(markup.glideProgress, 0), 1))
                    let slid = CGRect(
                        x: source.minX + (target.minX - source.minX) * progress, y: target.minY,
                        width: source.width + (target.width - source.width) * progress, height: target.height
                    )
                    rects = [slid]
                }
                color(accent).setFill()
                for rect in rects {
                    UIBezierPath(roundedRect: rect, cornerRadius: min(spec.spokenBoxRadius * layout.unit, rect.height / 2)).fill()
                }
                // On its box the word reads by itself: no outline, no shadow, the ink that reads best on the box.
                storage.addAttribute(.foregroundColor, value: color(accent.readableInk), range: litRange)
                storage.removeAttribute(.strokeWidth, range: litRange)
                storage.removeAttribute(.shadow, range: litRange)
            case .pop:
                storage.addAttribute(.foregroundColor, value: color(accent), range: litRange)
                if markup.popScale != 1 { popped = litRange }
            }
        }
        guard let popped else {
            drawGlyphs(all, layout: layout, spec: spec)
            return
        }
        // Every word but the popped one in place, then the popped one bigger around its own middle, never into the words beside
        // it: it grows only as far as the room on its line leaves, a space kept.
        let word = layout.manager.glyphRange(forCharacterRange: popped, actualCharacterRange: nil)
        drawGlyphs(NSRange(location: all.location, length: word.location - all.location), layout: layout, spec: spec)
        drawGlyphs(NSRange(location: NSMaxRange(word), length: NSMaxRange(all) - NSMaxRange(word)), layout: layout, spec: spec)
        let bounds = layout.manager.boundingRect(forGlyphRange: word, in: layout.container).offsetBy(dx: layout.origin.x, dy: layout.origin.y)
        let neighbors = [markup.lit.map { $0 - 1 }, markup.lit.map { $0 + markup.litCount }].compactMap { $0 }.compactMap { range($0) }.map { characters in
            layout.manager.boundingRect(
                forGlyphRange: layout.manager.glyphRange(forCharacterRange: characters, actualCharacterRange: nil), in: layout.container
            ).offsetBy(dx: layout.origin.x, dy: layout.origin.y)
        }
        let size = (storage.attribute(.font, at: popped.location, effectiveRange: nil) as? UIFont)?.pointSize ?? bounds.height
        let room = Self.popRoom(for: bounds, beside: neighbors, in: layout.size, fontSize: size, spec: spec, asked: CGFloat(markup.popScale))
        context.saveGState()
        context.translateBy(x: bounds.midX + room.shift, y: bounds.midY)
        context.scaleBy(x: room.scale, y: room.scale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        drawGlyphs(word, layout: layout, spec: spec)
        context.restoreGState()
    }

    /// How big a popped word (`bounds`) may grow toward `asked`, and how far it moves while growing: into the room on its line
    /// up to the words beside it (`neighbors`, on the same line) and the drawing's edges, more toward the side that has more (the
    /// last word of a line grows into the free end), always keeping about a space clear beside the outlines of both words. The
    /// layout of a style that pops leaves the room (`CaptionStyleSpec.wordSpacing`).
    static func popRoom(
        for bounds: CGRect, beside neighbors: [CGRect], in size: CGSize, fontSize: CGFloat, spec: CaptionStyleSpec, asked: CGFloat
    ) -> (scale: CGFloat, shift: CGFloat) {
        guard bounds.width > 0, bounds.height > 0, asked > 1 else { return (max(1, asked), 0) }
        let outline = spec.outline.map { CGFloat($0.width) / 100 * fontSize * (spec.strokesOutside ? 2 : 1) } ?? 0
        let kept = fontSize * 0.18 + outline
        var left = bounds.minX - 2
        var right = size.width - bounds.maxX - 2
        for neighbor in neighbors where abs(neighbor.midY - bounds.midY) < bounds.height / 2 {
            if neighbor.maxX <= bounds.midX { left = min(left, bounds.minX - neighbor.maxX - kept) }
            if neighbor.minX >= bounds.midX { right = min(right, neighbor.minX - bounds.maxX - kept) }
        }
        left = max(0, left)
        right = max(0, right)
        let vertical = max(0, min(bounds.minY, size.height - bounds.maxY))
        let scale = max(1, min(asked, 1 + (left + right) / bounds.width, 1 + 2 * vertical / bounds.height))
        // Half the growth to each side where there is room, the rest to the side that has it.
        let growth = (scale - 1) * bounds.width
        var leftward = min(left, growth / 2)
        let rightward = min(right, growth - leftward)
        leftward = growth - rightward
        return (scale, (rightward - leftward) / 2)
    }
}
