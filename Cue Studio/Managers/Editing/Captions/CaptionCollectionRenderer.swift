//
//  CaptionCollectionRenderer.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// One TextKit layout for every state of a line: changing ink never changes glyph positions.
/// Drawn lazily through the existing compositor cache, identically in thumbnails and exports.
nonisolated enum CaptionCollectionRenderer {
    struct Layout {
        let storage: NSTextStorage
        let manager: NSLayoutManager
        let container: NSTextContainer
        let size: CGSize
        let origin: CGPoint
        let unit: CGFloat
    }

    /// Where a line's drawing goes on the frame and what it is named by: the drawing is made from the same line and settings
    /// when it shows (`image`).
    struct Placement {
        let text: TextOverlay
        let size: CGSize
        let origin: CGPoint
        let widthFraction: CGFloat
    }

    /// How the collection's lines come and go: a still line, faded, words appearing, the word said
    /// lit (the theme's own way: Cue boxes it, the others color it) or boxed. A line whose words
    /// have no times of their own (written or corrected by hand) gets the same effects over its
    /// words shared across its time (`CaptionCue.lineWords`). A line with a style of its own (`CaptionLineStyle`) is drawn
    /// bigger, and an emphasized one shows lit whole for its whole time instead of word by word. Captions with motion
    /// (`CaptionSettings.motion`) play it instead (`motionOverlays`); edits saved before it play `animation` as they did.
    static func overlays(
        _ cues: [CaptionCue], settings: CaptionSettings, position: CaptionPosition, frame: CGSize, animation: CaptionAnimation = .line
    ) -> [FrameOverlay] {
        layOutAhead(cues, settings: settings, position: position, frame: frame)
        if let motion = settings.motion {
            return motionOverlays(cues, settings: settings, motion: motion, position: position, frame: frame)
        }
        let reveal = effectiveAnimation(settings: settings, animation: animation)
        return cues.flatMap { cue in
            let settings = styled(settings, for: cue.lineStyle)
            let words = cue.lineWords
            let breaks = cue.lineBreaks
            let marks = cue.shownEmphasis
            guard let placed = placement(cue, settings: settings, position: position, frame: frame) else { return [FrameOverlay]() }
            let style: WordEmphasis.Style = switch reveal {
            case .groups: .reveal
            case .box: .box(fill: .yellow, text: .black)
            default: .color(.yellow)
            }
            func overlay(_ span: TimeSpan, index: Int?, wholeLine: Bool = false) -> FrameOverlay {
                // A line lit whole takes the color the word said takes (boxed where the reveal boxes it), never the reveal.
                let emphasis = wholeLine
                    ? WordEmphasis.wholeLine(words.map(\.text), style: reveal == .box ? style : .color(.yellow), breaks: breaks)
                    : index.map { WordEmphasis(words: words.map(\.text), index: $0, style: style, breaks: breaks) }
                var overlay = FrameOverlay(
                    lazyText: LazyText(text: placed.text, emphasis: emphasis, frameWidth: frame.width, widthFraction: placed.widthFraction,
                                       collection: settings, frameHeight: frame.height,
                                       markup: marks.isEmpty ? nil : CaptionMarkup(emphasized: marks)),
                    size: placed.size, origin: placed.origin, span: span
                )
                if reveal == .fade { overlay.fade = CaptionAnimation.fadeDuration }
                return overlay
            }
            let spec = settings.spec
            /// The line coming in on its first state and going out on its last.
            func entered(_ states: [FrameOverlay]) -> [FrameOverlay] {
                var states = states
                guard let first = states.indices.first, let last = states.indices.last else { return states }
                states[first].fadeIn = spec.entry.fade
                states[first].popScale = spec.entry.popScale
                states[first].popDuration = spec.entry.popDuration
                states[last].fadeOut = spec.entry.fade
                return states
            }
            if cue.lineStyle?.isEmphasized == true, !words.isEmpty {
                return entered([overlay(cue.span, index: nil, wholeLine: true)])
            }
            guard reveal.followsWords, !words.isEmpty else { return entered([overlay(cue.span, index: nil)]) }
            // Each word lights over its own interval; gaps between measured words remain plain.
            var states: [FrameOverlay] = []
            var cursor = cue.start
            // Words appearing: nothing shows before the first word is said.
            if reveal == .groups, let first = words.first { cursor = max(cue.start, first.start) }
            for index in words.indices {
                let word = words[index]
                let start = max(cursor, word.start, cue.start)
                let end = min(cue.end, word.end, index + 1 < words.count ? words[index + 1].start : cue.end)
                if start > cursor { states.append(overlay(TimeSpan(start: cursor, end: start), index: nil)) }
                if end > start { states.append(overlay(TimeSpan(start: start, end: end), index: index)) }
                cursor = max(cursor, end)
            }
            if cursor < cue.end { states.append(overlay(TimeSpan(start: cursor, end: cue.end), index: nil)) }
            return entered(states.isEmpty ? [overlay(cue.span, index: nil)] : states)
        }
    }

    /// Where `cue` is drawn with `settings` (its own line style already on them) and how big, inside the safe area; nil when
    /// there is nothing to draw.
    static func placement(_ cue: CaptionCue, settings: CaptionSettings, position: CaptionPosition, frame: CGSize) -> Placement? {
        let line = CaptionText.joined(cue.lineWords.map(\.text), breaks: cue.lineBreaks)
        let text: TextOverlay
        let size: CGSize
        let widthFraction: CGFloat
        if let look = settings.customLook {
            let custom = customCaption(line, look: look, settings: settings, frame: frame)
            text = custom.text
            widthFraction = custom.widthFraction
            // Whole pixels, as the image is drawn: the box placed is the box drawn.
            let measured = TextOverlayRenderer.size(for: text, frameWidth: frame.width, widthFraction: widthFraction)
            size = CGSize(width: measured.width.rounded(.up), height: measured.height.rounded(.up))
            guard size.width > 0, size.height > 0 else { return nil }
        } else {
            text = TextOverlay.caption(line, look: TypePreset.cue.look(for: .caption), position: position, span: cue.span)
            widthFraction = 0.8
            let marks = cue.shownEmphasis
            // Laid out once per line and look (`CaptionLineSizes`): a build that changes no line lays none out again.
            let laidOut = CaptionLineSizes.size(text.text, settings: settings, frame: frame, emphasis: marks) {
                layout(text.text, settings: settings, frame: frame, emphasis: marks)?.size
            }
            guard let laidOut else { return nil }
            size = laidOut
        }
        let safe = contentRect(settings, frame: frame)
        let requested = settings.center ?? OverlayPoint(x: Double(safe.midX / frame.width), y: position.verticalFraction)
        let x = min(max(CGFloat(requested.clamped.x) * frame.width, safe.minX + size.width / 2), safe.maxX - size.width / 2)
        let y = min(max(CGFloat(requested.clamped.y) * frame.height, safe.minY + size.height / 2), safe.maxY - size.height / 2)
        let origin = CGPoint(x: (x - size.width / 2).rounded(), y: (frame.height - y - size.height / 2).rounded())
        return Placement(text: text, size: size, origin: origin, widthFraction: widthFraction)
    }

    /// A long take's lines not laid out yet are laid out side by side, on every core (each layout is its own TextKit
    /// objects), before the overlays are made from them: the first build of an hour of captions waits for the slowest core,
    /// not for every line in turn.
    private static func layOutAhead(_ cues: [CaptionCue], settings: CaptionSettings, position: CaptionPosition, frame: CGSize) {
        guard cues.count > 24, settings.customLook == nil else { return }
        var seen = Set<CaptionLineSizes.Key>()
        let missing = cues.compactMap { cue -> CaptionLineSizes.Key? in
            let line = CaptionText.joined(cue.lineWords.map(\.text), breaks: cue.lineBreaks)
            let text = TextOverlay.caption(line, look: TypePreset.cue.look(for: .caption), position: position, span: cue.span).text
            let key = CaptionLineSizes.Key(text: text, settings: styled(settings, for: cue.lineStyle), frame: frame, emphasis: cue.shownEmphasis)
            guard !CaptionLineSizes.isKnown(key), seen.insert(key).inserted else { return nil }
            return key
        }
        DispatchQueue.concurrentPerform(iterations: missing.count) { index in
            let key = missing[index]
            _ = CaptionLineSizes.size(key.text, settings: key.settings, frame: key.frame, emphasis: key.emphasis) {
                layout(key.text, settings: key.settings, frame: key.frame, emphasis: key.emphasis)?.size
            }
        }
    }

    /// `text` drawn as `settings` draw it: the word lit as `emphasis` says (edits saved before motion), or as `markup` says
    /// with the words marked for emphasis (`CaptionMarkup`).
    static func image(
        _ text: String, settings: CaptionSettings, frame: CGSize, emphasis: WordEmphasis? = nil, markup: CaptionMarkup? = nil
    ) -> UIImage? {
        if let look = settings.customLook {
            return customImage(text, look: look, settings: settings, frame: frame, emphasis: emphasis)
        }
        guard let layout = layout(text, settings: settings, frame: frame, emphasis: markup?.emphasized ?? []) else { return nil }
        let spec = settings.spec
        let display = spec.letterCase.shown(text)
        let range = emphasis?.range(in: display, letterCase: spec.letterCase)
        let all = layout.manager.glyphRange(for: layout.container)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: layout.size, format: format).image { renderer in
            var lines: [CGRect] = []
            layout.manager.enumerateLineFragments(forGlyphRange: all) { _, used, _, _, _ in
                lines.append(used.offsetBy(dx: layout.origin.x, dy: layout.origin.y))
            }
            switch spec.plate {
            case .none:
                break
            case .block(let color, let radius, let insetX, let insetY):
                if let first = lines.first {
                    let box = lines.dropFirst().reduce(first) { $0.union($1) }.insetBy(dx: -insetX * layout.unit, dy: -insetY * layout.unit)
                    Self.color(color).setFill()
                    UIBezierPath(roundedRect: box, cornerRadius: min(radius * layout.unit, box.height / 2)).fill()
                }
            case .perLine(let color, let radius, let insetX, let insetY):
                Self.color(color).setFill()
                for line in lines {
                    let box = line.insetBy(dx: -insetX * layout.unit, dy: -insetY * layout.unit)
                    UIBezierPath(roundedRect: box, cornerRadius: min(radius * layout.unit, box.height / 2)).fill()
                }
            }
            if let markup, markup.playsWords {
                drawPlaying(markup, text: text, display: display, layout: layout, settings: settings, in: renderer.cgContext)
                return
            }
            if let range, emphasis?.style == .reveal {
                // Only the words said so far.
                let hidden = NSRange(location: range.location + range.length, length: (display as NSString).length - range.location - range.length)
                if hidden.length > 0 {
                    layout.storage.addAttribute(.foregroundColor, value: UIColor.clear, range: hidden)
                    layout.storage.removeAttribute(.shadow, range: hidden)
                    layout.storage.removeAttribute(.strokeWidth, range: hidden)
                }
            } else if let range {
                let accent = color(settings.highlightColor)
                let boxes = if case .box = emphasis?.style { true } else { spec.highlightsWithBox }
                if boxes {
                    accent.setFill()
                    let glyphs = layout.manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    layout.manager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                                         in: layout.container) { rect, _ in
                        let box = rect.offsetBy(dx: layout.origin.x, dy: layout.origin.y).insetBy(dx: -4 * layout.unit, dy: -1 * layout.unit)
                        UIBezierPath(roundedRect: box, cornerRadius: 5 * layout.unit).fill()
                    }
                    layout.storage.addAttribute(.foregroundColor, value: UIColor.black, range: range)
                } else {
                    layout.storage.addAttribute(.foregroundColor, value: accent, range: range)
                }
            }
            drawGlyphs(all, layout: layout, spec: spec)
        }
    }

    /// Adds `room` points to every space between words (a style whose word being said pops); nothing with no room asked.
    private static func spaceOut(_ storage: NSTextStorage, by room: CGFloat) {
        guard room > 0 else { return }
        let text = storage.string as NSString
        var search = NSRange(location: 0, length: text.length)
        while search.length > 0 {
            let found = text.range(of: " ", options: [], range: search)
            guard found.location != NSNotFound else { break }
            let kern = (storage.attribute(.kern, at: found.location, effectiveRange: nil) as? CGFloat) ?? 0
            storage.addAttribute(.kern, value: kern + room, range: found)
            search = NSRange(location: NSMaxRange(found), length: text.length - NSMaxRange(found))
        }
    }

    /// The glyphs as `spec` draws them: a halo's passes over one another, so it is dense where the letters meet the picture;
    /// an outline outside the letters (`strokesOutside`) drawn first, twice as wide and under its shadow, the letters filled
    /// over it so it never eats into them.
    static func drawGlyphs(_ glyphs: NSRange, layout: Layout, spec: CaptionStyleSpec) {
        guard glyphs.length > 0 else { return }
        let passes = max(1, spec.shadow?.passes ?? 1)
        guard spec.strokesOutside, spec.outline != nil else {
            for _ in 0..<passes { layout.manager.drawGlyphs(forGlyphRange: glyphs, at: layout.origin) }
            return
        }
        let storage = layout.storage
        let characters = layout.manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var strokes: [(range: NSRange, width: CGFloat)] = []
        storage.enumerateAttribute(.strokeWidth, in: characters) { value, range, _ in
            if let width = (value as? NSNumber).map({ CGFloat(truncating: $0) }) { strokes.append((range, width)) }
        }
        var shadows: [(range: NSRange, shadow: Any)] = []
        storage.enumerateAttribute(.shadow, in: characters) { value, range, _ in
            if let value { shadows.append((range, value)) }
        }
        // The outline alone (a positive width strokes without filling), with the shadow under it, its corners round: a stroke
        // this thick would otherwise end in spikes at the letters' sharp corners (the end of an "e", the points of a "w").
        for stroke in strokes { storage.addAttribute(.strokeWidth, value: abs(stroke.width) * 2, range: stroke.range) }
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setLineJoin(.round)
        context?.setLineCap(.round)
        for _ in 0..<passes { layout.manager.drawGlyphs(forGlyphRange: glyphs, at: layout.origin) }
        context?.restoreGState()
        // The letters, filled, over it.
        storage.removeAttribute(.strokeWidth, range: characters)
        storage.removeAttribute(.shadow, range: characters)
        layout.manager.drawGlyphs(forGlyphRange: glyphs, at: layout.origin)
        for stroke in strokes { storage.addAttribute(.strokeWidth, value: stroke.width, range: stroke.range) }
        for shadow in shadows { storage.addAttribute(.shadow, value: shadow.shadow, range: shadow.range) }
    }

    /// What actually plays: a theme set not to follow words shows the line (faded or still);
    /// one that follows them lights the word said unless words appear or a box is picked.
    /// Edits made before Reveal (followsWords on, animation Line) keep lighting the word.
    static func effectiveAnimation(settings: CaptionSettings, animation: CaptionAnimation) -> CaptionAnimation {
        guard settings.followsWords else { return animation == .fade ? .fade : .line }
        switch animation {
        case .groups, .box, .highlight: return animation
        case .line, .fade: return .highlight
        }
    }

    /// The collection's settings for one line: its own size on top of the collection's (kept inside the size range).
    static func styled(_ settings: CaptionSettings, for style: CaptionLineStyle?) -> CaptionSettings {
        guard let style, style.size != .regular else { return settings }
        var sized = settings
        sized.sizeScale = settings.clampedScale * style.size.scale
        return sized
    }

    static func color(_ color: CaptionStyleSpec.RGB) -> UIColor {
        UIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    static func color(_ accent: CaptionAccent) -> UIColor {
        let parts = accent.components
        return UIColor(red: parts.red, green: parts.green, blue: parts.blue, alpha: 1)
    }

    static func contentRect(_ settings: CaptionSettings, frame: CGSize) -> CGRect {
        let margins = frame.width > frame.height ? SafeZoneMargins(top: 5, bottom: 7, left: 6, right: 6) : settings.safeMargins
        let unit = margins.unitContentRect
        return CGRect(x: unit.minX * frame.width, y: unit.minY * frame.height, width: unit.width * frame.width, height: unit.height * frame.height)
    }

    // MARK: - A copied look

    /// A line in a text's look copied onto the captions (`CaptionSettings.customLook`), drawn by the
    /// texts' renderer. It keeps the captions' size: the preset's own type size at the collection's
    /// scale (measured, like the preset, on the frame's shorter side), never the title's. Its lines
    /// wrap inside the safe area, where the collection places them.
    static func customCaption(_ line: String, look: TextLook, settings: CaptionSettings, frame: CGSize) -> (text: TextOverlay, widthFraction: CGFloat) {
        let width = max(frame.width, 1)
        let points = settings.spec.baseSize * settings.clampedScale * Double(min(frame.width, frame.height) / width)
        var sized = look
        sized.sizeScale = points / TextLook.captionBaseSize
        let text = TextOverlay.caption(line, look: sized, position: .bottom, span: TimeSpan(start: 0, end: 0))
        let safe = contentRect(settings, frame: frame)
        let widthFraction = min(TextOverlayRenderer.captionWidthFraction, max(0.3, safe.width / width))
        return (text, widthFraction)
    }

    /// The word being said stands out the collection's way (Cue boxes it, the others color it, Words
    /// shows only the words said so far), in its highlight color.
    private static func customImage(_ line: String, look: TextLook, settings: CaptionSettings, frame: CGSize, emphasis: WordEmphasis?) -> UIImage? {
        let custom = customCaption(line, look: look, settings: settings, frame: frame)
        let boxes = settings.spec.highlightsWithBox
        let lit = emphasis.map { emphasis in
            let style: WordEmphasis.Style = switch emphasis.style {
            case .reveal: .reveal
            case .box: .box(fill: .yellow, text: .black)
            case .color where boxes: .box(fill: .yellow, text: .black)
            case .color: .color(.yellow)
            }
            return WordEmphasis(words: emphasis.words, index: emphasis.index, style: style)
        }
        return TextOverlayRenderer.image(
            for: custom.text, frameWidth: frame.width, widthFraction: custom.widthFraction, emphasis: lit,
            highlight: color(settings.highlightColor)
        )
    }

    // MARK: - Layout

    /// How `text` lays out in the collection's type at its own size, never shrunk: the lines it takes across the whole room,
    /// and whether one of its words alone is wider than the room. What a caption format cuts lines by (`CaptionBlocking`),
    /// measured as the drawing measures: font, weight, size, capitals, letter spacing and the room left by the margins and
    /// the plate, and the words marked for emphasis at their size. Nil when there is nothing to lay out.
    static func measure(
        _ text: String, settings: CaptionSettings, frame: CGSize, emphasis: Set<Int> = []
    ) -> (lines: Int, overlong: Bool)? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, min(frame.width, frame.height) > 0 else { return nil }
        let spec = settings.spec
        let display = spec.letterCase.shown(text)
        let unit = min(frame.width, frame.height) / TextOverlayRenderer.referenceWidth
        let padding = 14 * unit
        let maxWidth = max(1, min(frame.width * spec.widthFraction, contentRect(settings, frame: frame).width) - padding * 2)
        let size = CGFloat(spec.baseSize) * settings.clampedScale * unit
        let font = CaptionFont.font(spec: spec, size: size, text: display)
        let kern = spec.tracking > 0 && TextShaping.allowsLetterSpacing(in: display) ? CGFloat(spec.tracking) * unit : 0
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if kern > 0 { attributes[.kern] = kern }
        if let outline = spec.outline { attributes[.strokeWidth] = -outline.width }
        let marked = WordEmphasis.ranges(of: emphasis, in: text, display: display, letterCase: spec.letterCase)
        var bigger = attributes
        bigger[.font] = CaptionFont.font(spec: spec, size: size * CGFloat(spec.emphasisScale), text: display)
        let words = CaptionText.words(in: display)
        let widest = words.enumerated().map { index, word in
            (word as NSString).size(withAttributes: marked[index] == nil ? attributes : bigger).width
        }.max() ?? 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = CGFloat(spec.lineSpacing) * unit
        attributes[.paragraphStyle] = paragraph
        let storage = NSTextStorage(string: display, attributes: attributes)
        for range in marked.values { storage.addAttribute(.font, value: bigger[.font] as Any, range: range) }
        spaceOut(storage, by: CGFloat(spec.wordSpacing) * size)
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        var count = 0
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, _, _ in count += 1 }
        return (count, widest > maxWidth)
    }

    /// `text` laid out in the collection's type: balanced over two lines when short, shrunk only when it still doesn't fit
    /// (`CaptionBlocking` cuts blocks to fit), the words at `emphasis` bigger and in the emphasis color.
    static func layout(_ text: String, settings: CaptionSettings, frame: CGSize, emphasis: Set<Int> = []) -> Layout? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, min(frame.width, frame.height) > 0 else { return nil }
        let spec = settings.spec
        let display = spec.letterCase.shown(text)
        let unit = min(frame.width, frame.height) / TextOverlayRenderer.referenceWidth
        let base = CGFloat(spec.baseSize)
        let padding = CGSize(width: 14 * unit, height: 9 * unit)
        let safe = contentRect(settings, frame: frame)
        let maxWidth = max(1, min(frame.width * spec.widthFraction, safe.width) - padding.width * 2)
        var pointSize = base * settings.clampedScale * unit
        // A format's blocks are cut to fit its lines at this size (`CaptionBlocking`): only a block that still doesn't (a word
        // wider than the room, a line written by hand) shrinks.
        let maxLines = settings.format?.maxLines ?? spec.maxLines
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = switch spec.alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.baseWritingDirection = ScriptDirection.isRightToLeft(language: nil, text: display) ? .rightToLeft : .leftToRight
        // Letters spaced out only where the writing allows it.
        let kern = spec.tracking > 0 && TextShaping.allowsLetterSpacing(in: display) ? CGFloat(spec.tracking) * unit : 0
        func measure(_ string: String, font: UIFont) -> CGFloat {
            (string as NSString).size(withAttributes: kern > 0 ? [.font: font, .kern: kern] : [.font: font]).width
        }
        // Fit a long indivisible word before TextKit can fall back to breaking its characters.
        let words = CaptionText.words(in: display)
        let marked = WordEmphasis.ranges(of: emphasis, in: text, display: display, letterCase: spec.letterCase)
        let scale = CGFloat(spec.emphasisScale)
        func wordWidths(_ size: CGFloat) -> [CGFloat] {
            let font = CaptionFont.font(spec: spec, size: size, text: display)
            let bigger = marked.isEmpty ? font : CaptionFont.font(spec: spec, size: size * scale, text: display)
            return words.enumerated().map { index, word in measure(word, font: marked[index] == nil ? font : bigger) }
        }
        let widest = wordWidths(pointSize).max() ?? 0
        if widest > maxWidth { pointSize *= maxWidth / widest }
        var result: Layout?
        // How much narrower than one line a short sentence is balanced to; widened before the type ever shrinks.
        var balanceRatio = CGFloat(spec.balanceRatio)
        for _ in 0..<32 {
            let font = CaptionFont.font(spec: spec, size: pointSize, text: display)
            paragraph.lineSpacing = CGFloat(spec.lineSpacing) * unit
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .paragraphStyle: paragraph, .foregroundColor: color(spec.textColor),
            ]
            if kern > 0 { attributes[.kern] = kern }
            if let outline = spec.outline {
                attributes[.strokeWidth] = -outline.width
                attributes[.strokeColor] = color(outline.color)
            }
            if let shade = spec.shadow {
                let shadow = NSShadow()
                shadow.shadowColor = color(shade.color).withAlphaComponent(shade.opacity)
                shadow.shadowBlurRadius = shade.blur * unit
                shadow.shadowOffset = CGSize(width: 0, height: shade.offsetY * unit)
                attributes[.shadow] = shadow
            }
            let storage = NSTextStorage(string: display, attributes: attributes)
            if !marked.isEmpty {
                let bigger = CaptionFont.font(spec: spec, size: pointSize * scale, text: display)
                for range in marked.values {
                    storage.addAttribute(.font, value: bigger, range: range)
                    storage.addAttribute(.foregroundColor, value: color(spec.emphasisColor), range: range)
                }
            }
            spaceOut(storage, by: CGFloat(spec.wordSpacing) * pointSize)
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            // Favor two balanced lines for a short sentence, while keeping the longest word whole.
            let fullWidth = marked.isEmpty && spec.wordSpacing == 0 ? measure(display, font: font) : storage.size().width
            let longest = marked.isEmpty ? (words.map { measure($0, font: font) }.max() ?? 0) : (wordWidths(pointSize).max() ?? 0)
            // A line broken by hand goes on a new line only where the creator put it.
            let balanced = display.contains("\n") ? maxWidth
                : words.count > spec.balanceFromWords ? max(longest + 2 * unit, fullWidth / balanceRatio) : fullWidth
            let width = min(maxWidth, max(1, balanced))
            let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            manager.ensureLayout(for: container)
            let glyphs = manager.glyphRange(for: container)
            var count = 0
            manager.enumerateLineFragments(forGlyphRange: glyphs) { _, _, _, _, _ in count += 1 }
            let bounds = manager.usedRect(for: container)
            let size = CGSize(width: ceil(width + padding.width * 2), height: ceil(bounds.height + padding.height * 2))
            result = Layout(storage: storage, manager: manager, container: container, size: size,
                            origin: CGPoint(x: padding.width, y: padding.height), unit: unit)
            if count <= maxLines, size.height <= safe.height { break }
            // Too many lines while the balanced width is still narrower than the room: widen it first. Shrinking the type
            // shrinks that width with it, so the line count would never drop and the caption would end up a few points tall.
            if count > maxLines, width < maxWidth - 0.5, balanceRatio > 1 {
                balanceRatio = max(1, balanceRatio * 0.85)
                continue
            }
            pointSize *= 0.9
        }
        return result
    }
}
