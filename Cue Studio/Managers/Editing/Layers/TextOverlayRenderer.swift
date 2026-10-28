//
//  TextOverlayRenderer.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// Draws texts laid over the video as images sized to the output frame, so the compositor only
/// places them. The preview and the export call the same code, and the editor measures the same
/// way to outline the selected text, so what is edited is what is exported. A text with an effect
/// (`TextEffect`) is drawn by the effects' own code (`TextEffectComposer`), at every moment it shows.
nonisolated enum TextOverlayRenderer {
    /// Texts are sized on a frame this many points wide, then scaled to the real one.
    static let referenceWidth: CGFloat = 402
    /// Widest a text can be, as a fraction of the frame's width.
    static let maxWidthFraction: CGFloat = 0.86

    /// Widest a caption line can be: a little narrower than a text, so lines stay short.
    static let captionWidthFraction: CGFloat = 0.8

    /// A text drawn with the room its box's shadow or its effect needs: the image is `box` grown by `bleed` on every side,
    /// centered on the same point.
    struct Drawing {
        let image: UIImage
        let box: CGSize
        let bleed: CGFloat
    }

    /// One overlay per text, at its place (turned as it is), visible while it shows.
    static func overlays(_ texts: [(text: TextOverlay, span: TimeSpan)], frame: CGSize, widthFraction: CGFloat = maxWidthFraction) -> [FrameOverlay] {
        texts.compactMap { overlay(for: $0.text, span: $0.span, frame: frame, widthFraction: widthFraction) }
    }

    /// Captions drawn with a type look (a preset or "My style"), each line while it is said, at
    /// `position`, as `animation` shows them: the same drawing as a text's, made when it shows.
    static func captions(
        _ cues: [CaptionCue], look: TextLook, position: CaptionPosition, frame: CGSize, animation: CaptionAnimation = .line,
        offset: Double = 0
    ) -> [FrameOverlay] {
        cues.flatMap { CaptionAnimator.overlays(for: $0, look: look, position: position, frame: frame, animation: animation, offset: offset) }
    }

    /// A translation shown with the original: smaller, just under it (over it at the bottom of
    /// the frame, so it stays clear of the platforms' buttons), a still line.
    static func secondCaptions(_ cues: [CaptionCue], look: TextLook, position: CaptionPosition, frame: CGSize) -> [FrameOverlay] {
        var smaller = look
        smaller.sizeScale = look.sizeScale * 0.8
        let offset = position == .bottom ? -0.07 : 0.07
        return captions(cues, look: smaller, position: position, frame: frame, animation: .line, offset: offset)
    }

    /// The text's box on a frame `frameWidth` wide (background and room for the shadow included).
    static func size(for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat = maxWidthFraction) -> CGSize {
        if let item = text.coverItem { return CoverCompositionRenderer.image(of: item, coverWidth: frameWidth)?.size ?? .zero }
        if let request = effectRequest(for: text, frameWidth: frameWidth, widthFraction: widthFraction) {
            return TextEffectCache.shared.layout(for: request)?.boxSize ?? .zero
        }
        return layout(for: text, frameWidth: frameWidth, widthFraction: widthFraction)?.size ?? .zero
    }

    /// The text as the video shows it, on a frame `frameWidth` wide, with the room around its box its shadow or its effect
    /// draws in: its effect `time` seconds into a text shown for `length` (at rest without a time). What the editor's copy
    /// under the finger, the panel's cards and the cover's title show.
    static func drawing(
        for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat = maxWidthFraction, time: TimeInterval? = nil,
        length: TimeInterval = 0
    ) -> Drawing? {
        if let item = text.coverItem {
            guard !text.isEmpty, let image = CoverCompositionRenderer.image(of: item, coverWidth: frameWidth) else { return nil }
            return Drawing(image: image, box: image.size, bleed: 0)
        }
        if let request = effectRequest(for: text, frameWidth: frameWidth, widthFraction: widthFraction) {
            guard let sprites = TextEffectCache.shared.sprites(for: request) else { return nil }
            let picture = time.map { TextEffectComposer.image(sprites, effect: request.effect, time: $0, length: length) } ?? sprites.rest()
            let extent = CGRect(origin: .zero, size: sprites.layout.drawingSize)
            guard let image = TextEffectComposer.context.createCGImage(
                picture, from: extent, format: .RGBA8, colorSpace: TextEffectPainter.colorSpace
            ) else { return nil }
            return Drawing(image: UIImage(cgImage: image), box: sprites.layout.boxSize, bleed: sprites.layout.room)
        }
        guard let layout = layout(for: text, frameWidth: frameWidth, widthFraction: widthFraction, room: true),
              let image = render(layout, text: text, frameWidth: frameWidth, emphasis: nil, highlight: nil) else { return nil }
        return Drawing(image: image, box: layout.size, bleed: layout.bleed)
    }

    /// The text drawn on a transparent image of its box, at 1 pixel per point (a caption line, the word being said). With
    /// `emphasis`, the word being said stands out (the box and the size stay those of the plain line, so the line doesn't
    /// move from one word to the next); `highlight` lights it in a caption collection's color instead of the emphasis's own.
    /// A box's shadow is the letters' here: nothing is drawn past the box.
    static func image(
        for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat = maxWidthFraction, emphasis: WordEmphasis? = nil,
        highlight: UIColor? = nil
    ) -> UIImage? {
        // A graphic is drawn by Cover Studio's own code, so it looks the same on the cover and in the video.
        if let item = text.coverItem { return text.isEmpty ? nil : CoverCompositionRenderer.image(of: item, coverWidth: frameWidth) }
        guard let layout = layout(for: text, frameWidth: frameWidth, widthFraction: widthFraction) else { return nil }
        return render(layout, text: text, frameWidth: frameWidth, emphasis: emphasis, highlight: highlight)
    }

    // MARK: - Overlays

    private static func overlay(for text: TextOverlay, span: TimeSpan, frame: CGSize, widthFraction: CGFloat) -> FrameOverlay? {
        // Drawn as big as its keyframes make it, so it stays sharp when they enlarge it.
        let sharpness = drawnScale(for: text)
        let width = frame.width * sharpness
        let content: (box: CGSize, bleed: CGFloat, make: (CGPoint) -> FrameOverlay)
        if let request = effectRequest(for: text, frameWidth: width, widthFraction: widthFraction) {
            guard let layout = TextEffectCache.shared.layout(for: request) else { return nil }
            let playback = TextEffectPlayback(request: request, length: span.duration, animates: text.playsEffectMotion)
            let box = CGSize(width: layout.boxSize.width / sharpness, height: layout.boxSize.height / sharpness)
            let bleed = layout.room / sharpness
            content = (box, bleed, { FrameOverlay(effect: playback, box: box, bleed: bleed, origin: $0, span: span) })
        } else {
            guard let drawing = drawing(for: text, frameWidth: width, widthFraction: widthFraction),
                  let image = CIImage(image: drawing.image) else { return nil }
            let box = CGSize(width: drawing.box.width / sharpness, height: drawing.box.height / sharpness)
            let bleed = drawing.bleed / sharpness
            content = (box, bleed, { FrameOverlay(image: image, box: box, bleed: bleed, origin: $0, span: span) })
        }
        let center = text.center.clamped
        let x = CGFloat(center.x) * frame.width - content.box.width / 2
        // Core Image measures y from the bottom.
        let y = frame.height * (1 - CGFloat(center.y)) - content.box.height / 2
        var overlay = content.make(CGPoint(x: x.rounded(), y: y.rounded()))
        overlay.drawnScale = sharpness
        overlay.rotation = text.rotation
        if !text.keyframes.isEmpty || text.animation != nil {
            overlay.motion = OverlayMotion(
                text.keyframes, animation: text.animation, length: span.duration,
                base: OverlayMotion.State(center: center, scale: 1, opacity: 1, rotation: text.rotation)
            )
            overlay.frameSize = frame
        }
        return overlay
    }

    /// How much bigger than its size a text is drawn: as big as its keyframes (or a slow zoom) make it, so it isn't an
    /// enlarged bitmap; never more than twice for an effect (its layers weigh four times as much).
    static func drawnScale(for text: TextOverlay) -> CGFloat {
        var biggest = text.keyframes.map(\.scale).max() ?? 1
        if text.animation?.preset == .gentleZoom { biggest = max(biggest, 1.2) }
        guard biggest > 1.05 else { return 1 }
        return CGFloat(min(biggest, text.effect == nil ? 3 : 2))
    }

    // MARK: - Drawing

    private static func render(_ layout: Layout, text: TextOverlay, frameWidth: CGFloat, emphasis: WordEmphasis?, highlight: UIColor?) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let range = emphasis?.range(in: text.displayText, uppercased: text.isUppercase)
        let room = layout.bleed
        let canvas = CGSize(width: layout.size.width + room * 2, height: layout.size.height + room * 2)
        return UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            let context = renderer.cgContext
            context.translateBy(x: room, y: room)
            if let fill = layout.background {
                context.saveGState()
                if let shadow = layout.boxShadow { setShadow(shadow, in: context) }
                fill.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: layout.size), cornerRadius: layout.cornerRadius).fill()
                context.restoreGState()
            }
            guard let emphasis, let range else {
                drawLetters(layout.string, layout: layout, in: context, plain: nil) { string in
                    string.draw(with: layout.textRect, options: [.usesLineFragmentOrigin], context: nil)
                }
                return
            }
            // Laid out once with TextKit, so the box sits exactly on the word it's drawn under.
            let storage = NSTextStorage(attributedString: layout.string)
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            let container = NSTextContainer(size: CGSize(width: layout.textRect.width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            var plain: NSRange?
            var hidden: NSRange?
            switch emphasis.style {
            case .color(let color):
                storage.addAttribute(.foregroundColor, value: highlight ?? Self.color(color), range: range)
            case .box(let fill, let ink):
                let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let unit = frameWidth / referenceWidth * layout.scale
                let word = manager.boundingRect(forGlyphRange: glyphs, in: container)
                    .offsetBy(dx: layout.textRect.minX, dy: layout.textRect.minY)
                    .insetBy(dx: -4 * unit, dy: -1 * unit)
                (highlight ?? Self.color(fill)).setFill()
                UIBezierPath(roundedRect: word, cornerRadius: 6 * unit).fill()
                storage.addAttribute(.foregroundColor, value: Self.color(ink), range: range)
                // No outline or shadow on the boxed word: it reads on its box.
                plain = range
            case .reveal:
                // Only the words said so far; the rest keep their place, unseen.
                let end = range.location + range.length
                let unsaid = NSRange(location: end, length: storage.length - end)
                if unsaid.length > 0 {
                    storage.addAttribute(.foregroundColor, value: UIColor.clear, range: unsaid)
                    hidden = unsaid
                }
            }
            let draw = { (string: NSAttributedString) in
                storage.setAttributedString(string)
                let all = manager.glyphRange(for: container)
                manager.drawBackground(forGlyphRange: all, at: layout.textRect.origin)
                manager.drawGlyphs(forGlyphRange: all, at: layout.textRect.origin)
            }
            if layout.lettering == .centered {
                // The first way, in one pass: the boxed word and the words not said yet without outline or shadow.
                for bare in [plain, hidden].compactMap(\.self) {
                    storage.removeAttribute(.strokeWidth, range: bare)
                    storage.removeAttribute(.shadow, range: bare)
                }
                draw(NSAttributedString(attributedString: storage))
                return
            }
            drawLetters(NSAttributedString(attributedString: storage), layout: layout, in: context, plain: plain, draw: draw)
        }
    }

    /// Draws the letters the way every text is drawn: the outline wholly outside them, behind the fill, with round joins (a
    /// stroke centered on their edges eats thin letters and shows where a variable font's overlapping strokes meet), and one
    /// shadow or glow under letters and outline together (one on every pass darkens the fill). `draw` draws the string it's
    /// given in the text's place; `plain` is drawn last, with neither outline nor shadow (a boxed word).
    private static func drawLetters(
        _ base: NSAttributedString, layout: Layout, in context: CGContext, plain: NSRange?, draw: (NSAttributedString) -> Void
    ) {
        let decorated = plain.map { recolored(base, keeping: $0, inside: false) } ?? base
        context.saveGState()
        if let shadow = layout.letterShadow {
            setShadow(shadow, in: context)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        if let outline = layout.outline {
            context.setLineJoin(.round)
            draw(stroked(decorated, color: outline, width: layout.outlineWidth))
        }
        draw(decorated)
        if layout.letterShadow != nil { context.endTransparencyLayer() }
        context.restoreGState()
        if let plain { draw(recolored(base, keeping: plain, inside: true)) }
    }

    /// `string` with an outline of `width` (percent of the size, positive: the stroke alone) wherever its letters show.
    private static func stroked(_ string: NSAttributedString, color: UIColor, width: CGFloat) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: string)
        copy.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: copy.length)) { value, range, _ in
            guard ((value as? UIColor)?.cgColor.alpha ?? 1) > 0.001 else { return }
            copy.addAttributes([.strokeWidth: width, .strokeColor: color], range: range)
        }
        return copy
    }

    /// `string` with only `range` showing (`inside`) or everything but it.
    private static func recolored(_ string: NSAttributedString, keeping range: NSRange, inside: Bool) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: string)
        let all = NSRange(location: 0, length: copy.length)
        if inside {
            if range.location > 0 { copy.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: range.location)) }
            let end = NSMaxRange(range)
            if end < all.length { copy.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: end, length: all.length - end)) }
        } else {
            copy.addAttribute(.foregroundColor, value: UIColor.clear, range: NSIntersectionRange(range, all))
        }
        return copy
    }

    private static func setShadow(_ shadow: Shadow, in context: CGContext) {
        context.setShadow(offset: CGSize(width: 0, height: shadow.drop), blur: shadow.blur, color: shadow.color.cgColor)
    }

    // MARK: - Layout

    /// A soft shadow: how far it falls (down is positive) and how much it spreads.
    private struct Shadow {
        let color: UIColor
        let blur: CGFloat
        let drop: CGFloat
    }

    private struct Layout {
        let string: NSAttributedString
        let size: CGSize
        let textRect: CGRect
        let background: UIColor?
        let cornerRadius: CGFloat
        /// The outline's color and width (percent of the letters' size, drawn outside them); nil for none.
        let outline: UIColor?
        let outlineWidth: CGFloat
        /// Under the letters (and their outline): a drop shadow or a glow.
        let letterShadow: Shadow?
        /// Under the box, when the text has one and a shadow, drawn in the room around it.
        let boxShadow: Shadow?
        /// How far the drawing reaches past the box: the box's shadow, or the letters' outline and shadow (`drawing` only).
        let bleed: CGFloat
        /// How much bigger the text is than when its block was measured (`TextBlock`): its metrics grow with it.
        let scale: CGFloat
        /// `centered`: the outline and the shadow are the string's own attributes, drawn in one pass.
        let lettering: TextLettering
    }

    private static func layout(for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat, room: Bool = false) -> Layout? {
        guard !text.isEmpty, frameWidth > 0 else { return nil }
        // A text resized as a whole grows everything it draws with its size.
        let scale = CGFloat(text.block?.scale(at: text.size) ?? 1)
        let unit = frameWidth / referenceWidth * scale
        let pointSize = CGFloat(text.size) * frameWidth / referenceWidth
        let font = font(for: text, size: pointSize)
        let paragraph = paragraphStyle(for: text)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color(text.color), .paragraphStyle: paragraph,
        ]
        // Letters spaced out only where the writing allows it (never Arabic, Hindi or Thai).
        if abs(text.tracking) > 0.000_1, TextShaping.allowsLetterSpacing(in: text.displayText) {
            attributes[.kern] = CGFloat(text.tracking) * pointSize
        }
        let filled = text.background != .none && text.backgroundOpacity > 0.001
        let centered = text.lettering == .centered
        if centered { addFirstWayLetters(of: text, unit: unit, to: &attributes) }
        let soft = Shadow(color: UIColor.black.withAlphaComponent(0.55), blur: 6 * unit, drop: 2 * unit)
        let boxShadow = !centered && room && filled && text.hasShadow && text.glow <= 0.001
            ? Shadow(color: UIColor.black.withAlphaComponent(0.32 * CGFloat(text.backgroundOpacity)), blur: 10 * unit, drop: 3 * unit)
            : nil
        let letterShadow: Shadow? = if centered {
            nil
        } else if text.glow > 0.001 {
            // A glow stands in for the drop shadow: the text's own light, spreading as far as the creator asks.
            Shadow(color: color(text.color).withAlphaComponent(CGFloat(0.55 + 0.4 * text.glow)), blur: glowRadius(text, unit: unit), drop: 0)
        } else if text.hasShadow, boxShadow == nil {
            soft
        } else {
            nil
        }
        let string = NSAttributedString(string: text.displayText, attributes: attributes)
        let glowRoom = text.background == .none ? glowRadius(text, unit: unit) * 0.9 : 0
        let padding: CGSize = switch text.background {
        case .none: CGSize(width: 8 * unit + glowRoom, height: 6 * unit + glowRoom)
        case .box: CGSize(width: 12 * unit, height: 6 * unit)
        case .pill: CGSize(width: 16 * unit, height: 7 * unit)
        }
        let maxWidth = lineLength(for: text, frameWidth: frameWidth, widthFraction: widthFraction) ?? (frameWidth * widthFraction - padding.width * 2)
        let bounds = string.boundingRect(
            with: CGSize(width: max(1, maxWidth), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        )
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        let size = CGSize(width: textSize.width + padding.width * 2, height: textSize.height + padding.height * 2)
        let background: UIColor? = filled ? color(text.backgroundColor).withAlphaComponent(CGFloat(text.backgroundOpacity)) : nil
        let cornerRadius: CGFloat = switch text.background {
        case .none: 0
        case .box: 8 * unit
        case .pill: min(size.height / 2, 24 * unit)
        }
        let outline: UIColor? = !centered && text.hasOutline ? (isDark(text.color) ? UIColor.white : UIColor.black) : nil
        // Past the box, with room asked for (`drawing`): the box's shadow, or as far as the letters' outline (outside them)
        // and their shadow reach beyond the padding. The box itself is what it always was, so a saved video's texts and
        // captions sit and measure as they did.
        let letterReach = (outline == nil ? 0 : pointSize * 0.04) + (letterShadow.map { $0.blur * 1.6 + abs($0.drop) } ?? 0)
        let bleed: CGFloat = if let boxShadow {
            ceil(boxShadow.blur * 1.6 + boxShadow.drop)
        } else if room {
            ceil(max(0, letterReach - min(padding.width, padding.height)))
        } else {
            0
        }
        return Layout(
            string: string, size: size,
            textRect: CGRect(origin: CGPoint(x: padding.width, y: padding.height), size: textSize),
            background: background, cornerRadius: cornerRadius, outline: outline, outlineWidth: 8, letterShadow: letterShadow,
            boxShadow: boxShadow, bleed: bleed, scale: scale, lettering: text.lettering
        )
    }

    /// The first way's outline and shadow (`TextLettering.centered`), as the string's own attributes: a stroke on the
    /// letters' edges over their fill, and a shadow (or a glow) cast by each pass.
    private static func addFirstWayLetters(of text: TextOverlay, unit: CGFloat, to attributes: inout [NSAttributedString.Key: Any]) {
        if text.glow > 0.001 {
            let glow = NSShadow()
            glow.shadowColor = color(text.color).withAlphaComponent(CGFloat(0.55 + 0.4 * text.glow))
            glow.shadowBlurRadius = glowRadius(text, unit: unit)
            glow.shadowOffset = .zero
            attributes[.shadow] = glow
        } else if text.hasShadow {
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 6 * unit
            shadow.shadowOffset = CGSize(width: 0, height: 2 * unit)
            attributes[.shadow] = shadow
        }
        if text.hasOutline {
            // Negative: stroke and fill.
            attributes[.strokeWidth] = -4.0
            attributes[.strokeColor] = text.color == .black ? UIColor.white : UIColor.black
        }
    }

    /// The longest a line of `text` can be, in pixels on a frame `frameWidth` wide, when it has a block of its own
    /// (`TextBlock`); nil: as wide as the frame allows.
    static func lineLength(for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat) -> CGFloat? {
        guard let block = text.block else { return nil }
        return CGFloat(block.width * block.scale(at: text.size)) * frameWidth / referenceWidth
    }

    /// How long `text`'s longest line is as it is laid out, in points on the design's frame: where a side handle starts
    /// making its block wider or narrower (`TextBlock`), so the first move already changes where lines break.
    static func laidOutLineWidth(of text: TextOverlay, widthFraction: CGFloat = maxWidthFraction) -> Double? {
        if let request = effectRequest(for: text, frameWidth: referenceWidth, widthFraction: widthFraction) {
            guard let layout = TextEffectCache.shared.layout(for: request), !layout.textBounds.isNull else { return nil }
            return Double(ceil(layout.textBounds.width))
        }
        guard text.coverItem == nil, let layout = layout(for: text, frameWidth: referenceWidth, widthFraction: widthFraction) else { return nil }
        return Double(layout.textRect.width)
    }

    /// How long `text`'s longest word is, in points on the design's frame: a side handle never makes its lines shorter, so
    /// no word is cut in two.
    static func longestWordWidth(of text: TextOverlay) -> Double {
        let pointSize = CGFloat(text.size)
        var attributes: [NSAttributedString.Key: Any] = [.font: font(for: text, size: pointSize)]
        if abs(text.tracking) > 0.000_1, TextShaping.allowsLetterSpacing(in: text.displayText) {
            attributes[.kern] = CGFloat(text.tracking) * pointSize
        }
        let widest = text.displayText.split(whereSeparator: \.isWhitespace).map { word in
            NSAttributedString(string: String(word), attributes: attributes).size().width
        }.max() ?? 0
        return Double(ceil(widest) + 1)
    }

    /// The longest a line of `text` can be now, in points on the design's frame at its size: its block's, or the frame's.
    /// What a block starts from when the text is first resized as a whole.
    static func currentLineWidth(of text: TextOverlay, widthFraction: CGFloat = maxWidthFraction) -> Double {
        if let block = text.block { return block.width * block.scale(at: text.size) }
        let unit: CGFloat = 1
        let padding: CGFloat = switch text.background {
        case .none: 8 * unit + glowRadius(text, unit: unit) * 0.9
        case .box: 12 * unit
        case .pill: 16 * unit
        }
        let effectPadding = text.effect.map { effectPadding(for: $0.kind, unit: unit, pointSize: CGFloat(text.size)).width } ?? padding
        return Double(referenceWidth * widthFraction - effectPadding * 2)
    }

    static func paragraphStyle(for text: TextOverlay) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        // Leading is where a line starts: the right in Arabic.
        let rightToLeft = ScriptDirection.isRightToLeft(language: nil, text: text.displayText)
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        paragraph.alignment = switch text.alignment {
        case .leading: rightToLeft ? .right : .left
        case .center: .center
        case .trailing: rightToLeft ? .left : .right
        }
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    /// How far a glow spreads: up to 26 pt on the design's frame.
    private static func glowRadius(_ text: TextOverlay, unit: CGFloat) -> CGFloat {
        CGFloat(text.glow) * 26 * unit
    }

    static func font(for text: TextOverlay, size: CGFloat) -> UIFont {
        TextFont.font(text.font, weight: text.weight, size: size, text: text.displayText)
    }

    /// A color dark enough that an outline around it is white.
    private static func isDark(_ color: OverlayColor) -> Bool {
        let parts = color.components
        return 0.2126 * parts.red + 0.7152 * parts.green + 0.0722 * parts.blue < 0.25
    }

    static func color(_ color: OverlayColor) -> UIColor {
        let parts = color.components
        return UIColor(red: parts.red, green: parts.green, blue: parts.blue, alpha: 1)
    }
}
