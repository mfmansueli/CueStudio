//
//  TextOverlayRenderer.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// Draws texts laid over the video as images sized to the output frame, so the compositor only
/// places them. The preview and the export call the same code, and the editor measures the same
/// way to outline the selected text, so what is edited is what is exported.
nonisolated enum TextOverlayRenderer {
    /// Texts are sized on a frame this many points wide, then scaled to the real one.
    static let referenceWidth: CGFloat = 402
    /// Widest a text can be, as a fraction of the frame's width.
    static let maxWidthFraction: CGFloat = 0.86

    /// Widest a caption line can be: a little narrower than a text, so lines stay short.
    static let captionWidthFraction: CGFloat = 0.8

    /// One overlay per text, at its place, visible while it shows.
    static func overlays(_ texts: [(text: TextOverlay, span: TimeSpan)], frame: CGSize, widthFraction: CGFloat = maxWidthFraction) -> [FrameOverlay] {
        texts.compactMap { entry in
            guard let image = image(for: entry.text, frameWidth: frame.width, widthFraction: widthFraction),
                  let ciImage = CIImage(image: image) else { return nil }
            let size = ciImage.extent.size
            let center = entry.text.center.clamped
            let x = CGFloat(center.x) * frame.width - size.width / 2
            // Core Image measures y from the bottom.
            let y = frame.height * (1 - CGFloat(center.y)) - size.height / 2
            var overlay = FrameOverlay(image: ciImage, origin: CGPoint(x: x.rounded(), y: y.rounded()), span: entry.span)
            if !entry.text.keyframes.isEmpty {
                overlay.motion = OverlayMotion(entry.text.keyframes)
                overlay.frameSize = frame
            }
            return overlay
        }
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
        layout(for: text, frameWidth: frameWidth, widthFraction: widthFraction)?.size ?? .zero
    }

    /// The text drawn on a transparent image of its box, at 1 pixel per point. With `emphasis`,
    /// the word being said stands out (the box and the size stay those of the plain line, so the
    /// line doesn't move from one word to the next).
    static func image(
        for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat = maxWidthFraction, emphasis: WordEmphasis? = nil
    ) -> UIImage? {
        guard let layout = layout(for: text, frameWidth: frameWidth, widthFraction: widthFraction) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let range = emphasis?.range(in: text.displayText, uppercased: text.isUppercase)
        return UIGraphicsImageRenderer(size: layout.size, format: format).image { _ in
            if let fill = layout.background {
                fill.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: layout.size), cornerRadius: layout.cornerRadius).fill()
            }
            guard let emphasis, let range else {
                layout.string.draw(with: layout.textRect, options: [.usesLineFragmentOrigin], context: nil)
                return
            }
            // Laid out once with TextKit, so the box sits exactly on the word it's drawn under.
            let string = NSMutableAttributedString(attributedString: layout.string)
            let storage = NSTextStorage(attributedString: string)
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            let container = NSTextContainer(size: CGSize(width: layout.textRect.width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            switch emphasis.style {
            case .color(let color):
                storage.addAttribute(.foregroundColor, value: Self.color(color), range: range)
            case .box(let fill, let ink):
                let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let unit = frameWidth / referenceWidth
                let word = manager.boundingRect(forGlyphRange: glyphs, in: container)
                    .offsetBy(dx: layout.textRect.minX, dy: layout.textRect.minY)
                    .insetBy(dx: -4 * unit, dy: -1 * unit)
                Self.color(fill).setFill()
                UIBezierPath(roundedRect: word, cornerRadius: 6 * unit).fill()
                storage.addAttribute(.foregroundColor, value: Self.color(ink), range: range)
                // No outline or shadow on the boxed word: it reads on its box.
                storage.removeAttribute(.strokeWidth, range: range)
                storage.removeAttribute(.shadow, range: range)
            case .reveal:
                // Only the words said so far; the rest keep their place, unseen.
                let end = range.location + range.length
                let hidden = NSRange(location: end, length: storage.length - end)
                if hidden.length > 0 {
                    storage.addAttribute(.foregroundColor, value: UIColor.clear, range: hidden)
                    storage.removeAttribute(.strokeWidth, range: hidden)
                    storage.removeAttribute(.shadow, range: hidden)
                }
            }
            let all = manager.glyphRange(for: container)
            manager.drawBackground(forGlyphRange: all, at: layout.textRect.origin)
            manager.drawGlyphs(forGlyphRange: all, at: layout.textRect.origin)
        }
    }

    // MARK: - Layout

    private struct Layout {
        let string: NSAttributedString
        let size: CGSize
        let textRect: CGRect
        let background: UIColor?
        let cornerRadius: CGFloat
    }

    private static func layout(for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat) -> Layout? {
        guard !text.isEmpty, frameWidth > 0 else { return nil }
        let unit = frameWidth / referenceWidth
        let pointSize = CGFloat(text.size) * unit
        let font = font(for: text, size: pointSize)
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
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color(text.color), .paragraphStyle: paragraph,
        ]
        if abs(text.tracking) > 0.000_1 {
            attributes[.kern] = CGFloat(text.tracking) * pointSize
        }
        if text.hasShadow {
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
        let string = NSAttributedString(string: text.displayText, attributes: attributes)
        let padding: CGSize = switch text.background {
        case .none: CGSize(width: 8 * unit, height: 6 * unit)
        case .box: CGSize(width: 12 * unit, height: 6 * unit)
        case .pill: CGSize(width: 16 * unit, height: 7 * unit)
        }
        let maxWidth = frameWidth * widthFraction - padding.width * 2
        let bounds = string.boundingRect(
            with: CGSize(width: max(1, maxWidth), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        )
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        let size = CGSize(width: textSize.width + padding.width * 2, height: textSize.height + padding.height * 2)
        let background: UIColor? = text.background == .none || text.backgroundOpacity <= 0.001
            ? nil : color(text.backgroundColor).withAlphaComponent(CGFloat(text.backgroundOpacity))
        let cornerRadius: CGFloat = switch text.background {
        case .none: 0
        case .box: 8 * unit
        case .pill: min(size.height / 2, 24 * unit)
        }
        return Layout(
            string: string, size: size,
            textRect: CGRect(origin: CGPoint(x: padding.width, y: padding.height), size: textSize),
            background: background, cornerRadius: cornerRadius
        )
    }

    private static func font(for text: TextOverlay, size: CGFloat) -> UIFont {
        TextFont.font(text.font, weight: text.weight, size: size, text: text.displayText)
    }

    static func color(_ color: OverlayColor) -> UIColor {
        let parts = color.components
        return UIColor(red: parts.red, green: parts.green, blue: parts.blue, alpha: 1)
    }
}
