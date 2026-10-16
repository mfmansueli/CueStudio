//
//  CoverCompositionRenderer.swift
//  Cue Studio
//

import CoreImage
import CoreText
import UIKit

/// Draws a Cover Studio cover: the picture as framed (or the two halves of a before/after), what the effect does to it, a
/// soft shade behind the words when they sit on the picture itself, the title (`CoverTextLayout`), the person cut out over the
/// words for "Text behind me" and "Outline me", then the graphics in their order. Every size is a share of the cover, so the
/// preview, the template thumbnails and the saved image are the same cover at different sizes.
nonisolated enum CoverCompositionRenderer {
    /// The cover's pictures: its own, and a before/after's second (nil: the same picture on both sides).
    struct Pictures {
        var main: UIImage
        var second: UIImage?
    }

    static func image(
        title: String, composition: CoverComposition, pictures: Pictures, size: CGSize, cutout: CoverDesignRenderer.Cutout?
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rect = CGRect(origin: .zero, size: size)
        let layout = titleLayout(title: title, composition: composition, size: size)
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            UIColor.black.setFill()
            context.fill(rect)
            drawPictures(composition, pictures: pictures, size: size, in: context)
            drawEffect(composition, size: size, in: context)
            if composition.title.background == .shadow || composition.title.background == .none, !layout.lines.isEmpty {
                drawScrim(behind: layout.bounds, size: size, in: context)
            }
            if let split = composition.split { drawSplitMarks(split, size: size, in: context) }
            drawTitle(layout, style: composition.title, size: size, in: context)
            if let cutout {
                cutout.outline?.draw(in: rect)
                cutout.person.draw(in: rect)
            }
            for item in composition.items { draw(item, size: size, in: context) }
        }
    }

    /// The title laid out on a cover of `size`, clear of the tags, the handle and a before/after's labels: what is drawn, and
    /// what Cover Studio's handles go around.
    static func titleLayout(title: String, composition: CoverComposition, size: CGSize) -> CoverTextLayout {
        var avoid = composition.items.filter { $0.kind.hasText }.map { frame(of: $0, coverSize: size) }
        if let split = composition.split, split.showsLabels { avoid += labelFrames(split, size: size) }
        return CoverTextLayout.layout(title: title, style: composition.title, coverSize: size, avoid: avoid)
    }

    /// Where an item is on a cover of `size` (top left), turn included.
    static func frame(of item: CoverItem, coverSize size: CGSize) -> CGRect {
        let shape = self.size(of: item, coverSize: size)
        let center = CGPoint(x: item.center.x * size.width, y: item.center.y * size.height)
        let box = CGRect(x: -shape.width / 2, y: -shape.height / 2, width: shape.width, height: shape.height)
        return box.applying(CGAffineTransform(rotationAngle: CGFloat(item.rotation))).offsetBy(dx: center.x, dy: center.y)
    }

    /// The pictures alone as framed at `size` (both halves of a before/after), for finding the person in them.
    static func picturesLayer(_ composition: CoverComposition, pictures: Pictures, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            drawPictures(composition, pictures: pictures, size: size, in: renderer.cgContext)
        }
    }

    // MARK: - Pictures

    /// The frames each picture fills: the whole cover, or the left and right of the divider.
    static func pictureFrames(_ composition: CoverComposition, size: CGSize) -> (main: CGRect, second: CGRect?) {
        guard let split = composition.split else { return (CGRect(origin: .zero, size: size), nil) }
        let x = (min(max(split.position, CoverSplit.positionRange.lowerBound), CoverSplit.positionRange.upperBound) * size.width).rounded()
        return (CGRect(x: 0, y: 0, width: x, height: size.height), CGRect(x: x, y: 0, width: size.width - x, height: size.height))
    }

    private static func drawPictures(_ composition: CoverComposition, pictures: Pictures, size: CGSize, in context: CGContext) {
        let frames = pictureFrames(composition, size: size)
        context.saveGState()
        context.clip(to: frames.main)
        pictures.main.draw(in: composition.framing.rect(for: pictures.main.size, in: frames.main))
        context.restoreGState()
        guard let second = frames.second, let split = composition.split else { return }
        let picture = pictures.second ?? pictures.main
        context.saveGState()
        context.clip(to: second)
        picture.draw(in: (pictures.second == nil ? composition.framing : split.framing).rect(for: picture.size, in: second))
        context.restoreGState()
    }

    // MARK: - Effect

    private static func drawEffect(_ composition: CoverComposition, size: CGSize, in context: CGContext) {
        let amount = min(max(composition.effectAmount, 0), 1)
        switch composition.effect {
        case .dim:
            UIColor.black.withAlphaComponent(0.15 + 0.5 * amount).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        case .blur:
            guard let snapshot = context.makeImage() else { return }
            let input = CIImage(cgImage: snapshot)
            let radius = size.width * (0.006 + 0.03 * amount)
            let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
            guard let output = CIContext(options: [.cacheIntermediates: false]).createCGImage(blurred, from: input.extent) else { return }
            UIImage(cgImage: output).draw(in: CGRect(origin: .zero, size: size))
        case .clean, .lift, .outline:
            break
        }
    }

    /// A soft dark band behind words that sit on the picture itself, so they read on a light one too.
    private static func drawScrim(behind bounds: CGRect, size: CGSize, in context: CGContext) {
        let reach = max(bounds.height * 0.9, size.height * 0.12)
        let top = max(0, bounds.minY - reach), bottom = min(size.height, bounds.maxY + reach)
        let colors = [
            UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.34).cgColor,
            UIColor.black.withAlphaComponent(0.34).cgColor, UIColor.black.withAlphaComponent(0).cgColor,
        ]
        let middleTop = (bounds.minY - top) / max(1, bottom - top), middleBottom = (bounds.maxY - top) / max(1, bottom - top)
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, middleTop, middleBottom, 1]
        ) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: bottom), options: [])
    }

    // MARK: - Before / after

    private static func drawSplitMarks(_ split: CoverSplit, size: CGSize, in context: CGContext) {
        let x = (min(max(split.position, CoverSplit.positionRange.lowerBound), CoverSplit.positionRange.upperBound) * size.width).rounded()
        UIColor.white.setFill()
        context.fill(CGRect(x: x - size.width * 0.006, y: 0, width: size.width * 0.012, height: size.height))
        guard split.showsLabels else { return }
        let frames = labelFrames(split, size: size)
        pill(split.beforeLabel, font: labelFont(size), fill: .white, box: frames[0], size: size, in: context)
        pill(split.afterLabel, font: labelFont(size), fill: color(.yellow), box: frames[1], size: size, in: context)
    }

    private static func labelFont(_ size: CGSize) -> UIFont {
        CoverTextLayout.font(.anton, size: size.width * 0.062)
    }

    /// BEFORE's and AFTER's pills, each in the middle of its half (an empty label has none: a zero rectangle).
    static func labelFrames(_ split: CoverSplit, size: CGSize) -> [CGRect] {
        let x = (min(max(split.position, CoverSplit.positionRange.lowerBound), CoverSplit.positionRange.upperBound) * size.width).rounded()
        let font = labelFont(size)
        let y = size.height * 0.34
        return [(split.beforeLabel, x / 2), (split.afterLabel, x + (size.width - x) / 2)].map { text, middle in
            guard !text.isEmpty else { return .zero }
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let height = font.ascender - font.descender
            let pad = CGSize(width: font.pointSize * 0.42, height: font.pointSize * 0.14)
            return CGRect(x: middle - width / 2 - pad.width, y: y - height / 2 - pad.height, width: width + pad.width * 2, height: height + pad.height * 2)
        }
    }

    /// Words on a rounded pill, in the ink that reads on `fill`.
    private static func pill(_ text: String, font: UIFont, fill: UIColor, box: CGRect, size: CGSize, in context: CGContext) {
        guard !text.isEmpty else { return }
        let string = NSAttributedString(string: text, attributes: [.font: font, foreground: ink(on: fill).cgColor])
        let line = CTLineCreateWithAttributedString(string)
        fill.setFill()
        UIBezierPath(roundedRect: box, cornerRadius: min(box.height / 2, size.width * 0.02)).fill()
        drawLine(line, at: CGPoint(x: box.minX + font.pointSize * 0.42, y: box.minY + font.pointSize * 0.14 + font.ascender), in: context)
    }

    // MARK: - Title

    private static let foreground = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
    private static let strokeWidth = NSAttributedString.Key(kCTStrokeWidthAttributeName as String)
    private static let strokeColor = NSAttributedString.Key(kCTStrokeColorAttributeName as String)

    private static func drawTitle(_ layout: CoverTextLayout, style: CoverTitleStyle, size: CGSize, in context: CGContext) {
        let accent = color(style.accent)
        if let kicker = layout.kicker {
            fill(UIBezierPath(roundedRect: kicker.frame, cornerRadius: kicker.frame.height * 0.28), with: accent)
            let text = NSMutableAttributedString(attributedString: kicker.text)
            text.addAttribute(foreground, value: ink(on: accent).cgColor, range: NSRange(location: 0, length: text.length))
            let line = CTLineCreateWithAttributedString(text)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? .systemFont(ofSize: 12)
            let baseline = kicker.frame.midY + (font.ascender + font.descender) / 2
            drawLine(line, at: CGPoint(x: kicker.frame.midX - width / 2, y: baseline), in: context)
        }
        if let number = layout.number {
            let text = NSMutableAttributedString(attributedString: number.text)
            text.addAttribute(foreground, value: accent.cgColor, range: NSRange(location: 0, length: text.length))
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: size.width * 0.008), blur: size.width * 0.03, color: UIColor.black.withAlphaComponent(0.55).cgColor
            )
            let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? .systemFont(ofSize: 12)
            drawLine(CTLineCreateWithAttributedString(text), at: CGPoint(x: number.frame.minX, y: number.frame.minY + font.ascender * 0.9), in: context)
            context.restoreGState()
        }
        guard !layout.lines.isEmpty else { return }
        let box = color(style.boxColor)
        var textColor = color(style.textColor)
        if style.background == .box {
            let pad = layout.font.pointSize * 0.32
            let frame = layout.block.insetBy(dx: -pad, dy: -pad * 0.6)
            fill(UIBezierPath(roundedRect: frame, cornerRadius: layout.font.pointSize * 0.3), with: box)
            // The words read on their box whatever colors were picked.
            if contrast(textColor, box) < 3 { textColor = ink(on: box) }
        }
        let highlighted = layout.highlightRanges
        if style.highlightStyle == .box {
            for rect in layout.highlightRects {
                fill(UIBezierPath(roundedRect: rect, cornerRadius: layout.font.pointSize * 0.14), with: accent)
            }
        }
        let highlightInk = style.highlightStyle == .box ? ink(on: accent) : accent
        for line in layout.lines {
            let part = layout.text.attributedSubstring(from: line.range)
            let colored = NSMutableAttributedString(attributedString: part)
            colored.addAttribute(foreground, value: textColor.cgColor, range: NSRange(location: 0, length: colored.length))
            for range in highlighted {
                let overlap = NSIntersectionRange(range, line.range)
                guard overlap.length > 0 else { continue }
                let local = NSRange(location: overlap.location - line.range.location, length: overlap.length)
                colored.addAttribute(foreground, value: highlightInk.cgColor, range: local)
            }
            let origin = CGPoint(x: line.frame.minX, y: line.frame.minY + line.baseline)
            if style.background == .outline {
                // Round joins: thin strokes of Thai or Arabic letters would otherwise grow spikes.
                let stroke = NSMutableAttributedString(attributedString: colored)
                stroke.addAttributes([strokeWidth: 13, strokeColor: UIColor.black.cgColor], range: NSRange(location: 0, length: stroke.length))
                context.saveGState()
                context.setLineJoin(.round)
                drawLine(CTLineCreateWithAttributedString(stroke), at: origin, in: context)
                context.restoreGState()
            }
            context.saveGState()
            if style.background == .shadow {
                context.setShadow(offset: CGSize(width: 0, height: layout.font.pointSize * 0.05), blur: layout.font.pointSize * 0.28,
                                  color: UIColor.black.withAlphaComponent(0.6).cgColor)
            }
            drawLine(CTLineCreateWithAttributedString(colored), at: origin, in: context)
            context.restoreGState()
        }
    }

    /// A line drawn with its baseline at `origin` (top-left coordinates).
    private static func drawLine(_ line: CTLine, at origin: CGPoint, in context: CGContext) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: origin.x, y: origin.y)
        context.scaleBy(x: 1, y: -1)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Items

    /// An item's size on a cover of `size`, before its turn.
    static func size(of item: CoverItem, coverSize size: CGSize) -> CGSize {
        let width = CGFloat(item.kind.baseWidth * item.scale) * size.width
        switch item.kind {
        case .arrow: return CGSize(width: width, height: width * 0.86)
        case .circle: return CGSize(width: width, height: width * 0.62)
        case .tag, .handle:
            let (text, font) = words(of: item, coverSize: size)
            let measured = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), nil, nil, nil))
            let pad = item.kind == .tag ? font.pointSize * 0.5 : font.pointSize * 0.1
            return CGSize(width: measured + pad * 2, height: (font.ascender - font.descender) + (item.kind == .tag ? font.pointSize * 0.36 : 0))
        }
    }

    private static func words(of item: CoverItem, coverSize size: CGSize) -> (NSAttributedString, UIFont) {
        let fontSize = size.width * 0.052 * CGFloat(item.scale)
        switch item.kind {
        case .handle:
            let font = TextFont.font(.spaceGrotesk, weight: .bold, size: fontSize, text: item.text)
            let handle = item.text.hasPrefix("@") ? item.text : "@" + item.text
            return (NSAttributedString(string: handle, attributes: [.font: font]), font)
        default:
            let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
            return (NSAttributedString(string: item.text.isEmpty ? " " : item.text, attributes: [.font: font]), font)
        }
    }

    private static func draw(_ item: CoverItem, size: CGSize, in context: CGContext) {
        let shape = Self.size(of: item, coverSize: size)
        let tint = color(item.color)
        context.saveGState()
        context.translateBy(x: item.center.x * size.width, y: item.center.y * size.height)
        context.rotate(by: CGFloat(item.rotation))
        let box = CGRect(x: -shape.width / 2, y: -shape.height / 2, width: shape.width, height: shape.height)
        context.setShadow(offset: CGSize(width: 0, height: size.width * 0.003), blur: size.width * 0.008, color: UIColor.black.withAlphaComponent(0.5).cgColor)
        switch item.kind {
        case .arrow:
            let path = arrowPath(in: box)
            path.lineWidth = box.width * 0.07
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            tint.setStroke()
            path.stroke()
        case .circle:
            let ring = UIBezierPath(ovalIn: box.insetBy(dx: box.width * 0.03, dy: box.width * 0.03))
            ring.lineWidth = box.width * 0.04
            tint.setStroke()
            ring.stroke()
        case .tag:
            fill(UIBezierPath(roundedRect: box, cornerRadius: box.height * 0.3), with: tint)
            let (text, font) = words(of: item, coverSize: size)
            let inked = NSMutableAttributedString(attributedString: text)
            inked.addAttribute(foreground, value: ink(on: tint).cgColor, range: NSRange(location: 0, length: inked.length))
            let line = CTLineCreateWithAttributedString(inked)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            context.setShadow(offset: .zero, blur: 0, color: nil)
            drawLine(line, at: CGPoint(x: -width / 2, y: (font.ascender + font.descender) / 2), in: context)
        case .handle:
            let (text, font) = words(of: item, coverSize: size)
            let inked = NSMutableAttributedString(attributedString: text)
            inked.addAttribute(foreground, value: tint.cgColor, range: NSRange(location: 0, length: inked.length))
            let line = CTLineCreateWithAttributedString(inked)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            drawLine(line, at: CGPoint(x: -width / 2, y: (font.ascender + font.descender) / 2), in: context)
        }
        context.restoreGState()
    }

    /// A hand-drawn arrow curving down to the right, in `box`.
    private static func arrowPath(in box: CGRect) -> UIBezierPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height) }
        let path = UIBezierPath()
        path.move(to: point(0.08, 0.12))
        path.addCurve(to: point(0.82, 0.82), controlPoint1: point(0.36, 0.12), controlPoint2: point(0.66, 0.34))
        path.move(to: point(0.82, 0.82))
        path.addLine(to: point(0.86, 0.52))
        path.move(to: point(0.82, 0.82))
        path.addLine(to: point(0.56, 0.74))
        return path
    }

    private static func fill(_ path: UIBezierPath, with color: UIColor) {
        color.setFill()
        path.fill()
    }

    // MARK: - Colors

    static func color(_ color: OverlayColor) -> UIColor {
        let rgb = color.components
        return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }

    /// Black or white, whichever reads better on `fill`.
    static func ink(on fill: UIColor) -> UIColor {
        contrast(.black, fill) >= contrast(.white, fill) ? .black : .white
    }

    /// WCAG contrast between two opaque colors.
    static func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ value: CGFloat) -> Double {
                let value = Double(value)
                return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }
}
