//
//  CaptionCollectionRenderer.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// One TextKit layout for every state of a line: changing ink never changes glyph positions.
/// Drawn lazily through the existing compositor cache, identically in thumbnails and exports.
nonisolated enum CaptionCollectionRenderer {
    private struct Layout {
        let storage: NSTextStorage
        let manager: NSLayoutManager
        let container: NSTextContainer
        let size: CGSize
        let origin: CGPoint
        let unit: CGFloat
    }

    /// How the collection's lines come and go: a still line, faded, words appearing, the word said
    /// lit (the theme's own way: Cue boxes it, the others color it) or boxed. A line whose words
    /// have no times of their own (written or corrected by hand) gets the same effects over its
    /// words shared across its time (`CaptionCue.lineWords`).
    static func overlays(
        _ cues: [CaptionCue], settings: CaptionSettings, position: CaptionPosition, frame: CGSize, animation: CaptionAnimation = .line
    ) -> [FrameOverlay] {
        let reveal = effectiveAnimation(settings: settings, animation: animation)
        return cues.flatMap { cue in
            let words = cue.lineWords
            let line = CaptionText.joined(words.map(\.text))
            // The drawing is named by its text (and, for a copied look, measured with it): the image is
            // made from the same line and settings when it shows (`image`).
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
                guard size.width > 0, size.height > 0 else { return [FrameOverlay]() }
            } else {
                text = TextOverlay.caption(line, look: TypePreset.cue.look(for: .caption), position: position, span: cue.span)
                widthFraction = 0.8
                guard let layout = layout(text.text, settings: settings, frame: frame) else { return [FrameOverlay]() }
                size = layout.size
            }
            let safe = contentRect(settings, frame: frame)
            let requested = settings.center ?? OverlayPoint(x: Double(safe.midX / frame.width), y: position.verticalFraction)
            let x = min(max(CGFloat(requested.clamped.x) * frame.width, safe.minX + size.width / 2), safe.maxX - size.width / 2)
            let y = min(max(CGFloat(requested.clamped.y) * frame.height, safe.minY + size.height / 2), safe.maxY - size.height / 2)
            let origin = CGPoint(x: (x - size.width / 2).rounded(), y: (frame.height - y - size.height / 2).rounded())
            let style: WordEmphasis.Style = switch reveal {
            case .groups: .reveal
            case .box: .box(fill: .yellow, text: .black)
            default: .color(.yellow)
            }
            func overlay(_ span: TimeSpan, index: Int?) -> FrameOverlay {
                let emphasis = index.map { WordEmphasis(words: words.map(\.text), index: $0, style: style) }
                var overlay = FrameOverlay(
                    lazyText: LazyText(text: text, emphasis: emphasis, frameWidth: frame.width, widthFraction: widthFraction,
                                       collection: settings, frameHeight: frame.height),
                    size: size, origin: origin, span: span
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

    static func image(_ text: String, settings: CaptionSettings, frame: CGSize, emphasis: WordEmphasis? = nil) -> UIImage? {
        if let look = settings.customLook {
            return customImage(text, look: look, settings: settings, frame: frame, emphasis: emphasis)
        }
        guard let layout = layout(text, settings: settings, frame: frame) else { return nil }
        let spec = settings.spec
        let display = spec.uppercase ? text.uppercased() : text
        let range = emphasis?.range(in: display, uppercased: spec.uppercase)
        let all = layout.manager.glyphRange(for: layout.container)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: layout.size, format: format).image { _ in
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
                    UIBezierPath(roundedRect: box, cornerRadius: radius * layout.unit).fill()
                }
            case .perLine(let color, let radius, let insetX, let insetY):
                Self.color(color).setFill()
                for line in lines {
                    UIBezierPath(roundedRect: line.insetBy(dx: -insetX * layout.unit, dy: -insetY * layout.unit), cornerRadius: radius * layout.unit).fill()
                }
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
            layout.manager.drawGlyphs(forGlyphRange: all, at: layout.origin)
        }
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

    private static func layout(_ text: String, settings: CaptionSettings, frame: CGSize) -> Layout? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, min(frame.width, frame.height) > 0 else { return nil }
        let spec = settings.spec
        let display = spec.uppercase ? text.uppercased() : text
        let unit = min(frame.width, frame.height) / TextOverlayRenderer.referenceWidth
        let base = CGFloat(spec.baseSize)
        let padding = CGSize(width: 14 * unit, height: 9 * unit)
        let safe = contentRect(settings, frame: frame)
        let maxWidth = max(1, min(frame.width * spec.widthFraction, safe.width) - padding.width * 2)
        var pointSize = base * settings.clampedScale * unit
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.baseWritingDirection = ScriptDirection.isRightToLeft(language: nil, text: display) ? .rightToLeft : .leftToRight
        // Letters spaced out only where the writing allows it.
        let kern = spec.tracking > 0 && CaptionFont.allowsTracking(in: display) ? CGFloat(spec.tracking) * unit : 0
        func measure(_ string: String, font: UIFont) -> CGFloat {
            (string as NSString).size(withAttributes: kern > 0 ? [.font: font, .kern: kern] : [.font: font]).width
        }
        // Fit a long indivisible word before TextKit can fall back to breaking its characters.
        let words = CaptionText.words(in: display)
        let initialFont = CaptionFont.font(spec: spec, size: pointSize, text: display)
        let widest = words.map { measure($0, font: initialFont) }.max() ?? 0
        if widest > maxWidth { pointSize *= maxWidth / widest }
        var result: Layout?
        for _ in 0..<24 {
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
                shadow.shadowColor = UIColor.black.withAlphaComponent(shade.opacity)
                shadow.shadowBlurRadius = shade.blur * unit
                shadow.shadowOffset = CGSize(width: 0, height: shade.offsetY * unit)
                attributes[.shadow] = shadow
            }
            let storage = NSTextStorage(string: display, attributes: attributes)
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            // Favor two balanced lines for a short sentence, while keeping the longest word whole.
            let fullWidth = measure(display, font: font)
            let longest = words.map { measure($0, font: font) }.max() ?? 0
            let balanced = words.count > spec.balanceFromWords ? max(longest + 2 * unit, fullWidth / spec.balanceRatio) : fullWidth
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
            if count <= spec.maxLines, size.height <= safe.height { break }
            pointSize *= 0.9
        }
        return result
    }
}
