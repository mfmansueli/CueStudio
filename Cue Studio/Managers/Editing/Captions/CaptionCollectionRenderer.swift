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
            let text = TextOverlay.caption(CaptionText.joined(words.map(\.text)), look: TypePreset.cue.look(for: .caption), position: position, span: cue.span)
            guard let layout = layout(text.text, settings: settings, frame: frame) else { return [FrameOverlay]() }
            let size = layout.size
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
                    lazyText: LazyText(text: text, emphasis: emphasis, frameWidth: frame.width, widthFraction: 0.8,
                                       collection: settings, frameHeight: frame.height),
                    size: size, origin: origin, span: span
                )
                if reveal == .fade { overlay.fade = CaptionAnimation.fadeDuration }
                return overlay
            }
            guard reveal.followsWords, !words.isEmpty else { return [overlay(cue.span, index: nil)] }
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
            return states.isEmpty ? [overlay(cue.span, index: nil)] : states
        }
    }

    static func image(_ text: String, settings: CaptionSettings, frame: CGSize, emphasis: WordEmphasis? = nil) -> UIImage? {
        guard let layout = layout(text, settings: settings, frame: frame) else { return nil }
        let theme = settings.theme
        let display = theme == .impact ? text.uppercased() : text
        let range = emphasis?.range(in: display, uppercased: theme == .impact)
        let all = layout.manager.glyphRange(for: layout.container)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: layout.size, format: format).image { _ in
            var lines: [CGRect] = []
            layout.manager.enumerateLineFragments(forGlyphRange: all) { _, used, _, _, _ in
                lines.append(used.offsetBy(dx: layout.origin.x, dy: layout.origin.y))
            }
            if theme == .editorial, let first = lines.first {
                let box = lines.dropFirst().reduce(first) { $0.union($1) }.insetBy(dx: -10 * layout.unit, dy: -4 * layout.unit)
                UIColor.black.withAlphaComponent(0.66).setFill()
                UIBezierPath(roundedRect: box, cornerRadius: 5 * layout.unit).fill()
            } else if theme == .pop {
                UIColor(red: 0.39, green: 0.16, blue: 0.77, alpha: 1).setFill()
                for line in lines {
                    UIBezierPath(roundedRect: line.insetBy(dx: -10 * layout.unit, dy: -2 * layout.unit), cornerRadius: 9 * layout.unit).fill()
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
                let boxes = if case .box = emphasis?.style { true } else { theme == .cue }
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

    static func color(_ accent: CaptionAccent) -> UIColor {
        let parts = accent.components
        return UIColor(red: parts.red, green: parts.green, blue: parts.blue, alpha: 1)
    }

    static func contentRect(_ settings: CaptionSettings, frame: CGSize) -> CGRect {
        let margins = frame.width > frame.height ? SafeZoneMargins(top: 5, bottom: 7, left: 6, right: 6) : settings.safeMargins
        let unit = margins.unitContentRect
        return CGRect(x: unit.minX * frame.width, y: unit.minY * frame.height, width: unit.width * frame.width, height: unit.height * frame.height)
    }

    private static func layout(_ text: String, settings: CaptionSettings, frame: CGSize) -> Layout? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, min(frame.width, frame.height) > 0 else { return nil }
        let display = settings.theme == .impact ? text.uppercased() : text
        let unit = min(frame.width, frame.height) / TextOverlayRenderer.referenceWidth
        let base: CGFloat = switch settings.theme {
        case .cue: 26
        case .impact: 30
        case .clean, .pop: 25
        case .editorial: 24
        }
        let padding = CGSize(width: 14 * unit, height: 9 * unit)
        let safe = contentRect(settings, frame: frame)
        let maxWidth = max(1, min(frame.width * 0.8, safe.width) - padding.width * 2)
        var pointSize = base * settings.clampedScale * unit
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.baseWritingDirection = ScriptDirection.isRightToLeft(language: nil, text: display) ? .rightToLeft : .leftToRight
        // Fit a long indivisible word before TextKit can fall back to breaking its characters.
        let words = CaptionText.words(in: display)
        let initialFont = CaptionFont.font(theme: settings.theme, size: pointSize, text: display)
        let widest = words.map { ($0 as NSString).size(withAttributes: [.font: initialFont]).width }.max() ?? 0
        if widest > maxWidth { pointSize *= maxWidth / widest }
        var result: Layout?
        for _ in 0..<24 {
            let font = CaptionFont.font(theme: settings.theme, size: pointSize, text: display)
            paragraph.lineSpacing = (settings.theme == .pop ? 5 : 1) * unit
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .paragraphStyle: paragraph,
                .foregroundColor: settings.theme == .editorial ? UIColor(white: 0.96, alpha: 1) : UIColor.white,
            ]
            if settings.theme == .impact {
                attributes[.strokeWidth] = -6.0
                attributes[.strokeColor] = UIColor.black
            } else if settings.theme == .clean || settings.theme == .cue {
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)
                shadow.shadowBlurRadius = 3 * unit
                shadow.shadowOffset = CGSize(width: 0, height: unit)
                attributes[.shadow] = shadow
            }
            let storage = NSTextStorage(string: display, attributes: attributes)
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            // Favor two balanced lines for a short sentence, while keeping the longest word whole.
            let fullWidth = (display as NSString).size(withAttributes: [.font: font]).width
            let longest = words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            let balanced = words.count > 4 ? max(longest + 2 * unit, fullWidth / 1.7) : fullWidth
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
            if count <= 3, size.height <= safe.height { break }
            pointSize *= 0.9
        }
        return result
    }
}
