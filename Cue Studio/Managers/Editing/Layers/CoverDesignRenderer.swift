//
//  CoverDesignRenderer.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// Draws the v26 cover design over a picture that already fills the cover: the picture's effect
/// (dim, blur), the words in the chosen layout with one highlighted, the person cut out over them
/// ("Text behind me") and the elements (arrow, circle, series tag, badge, handle). Every size is a
/// share of the cover's width or height, so the preview and the saved image are the same cover.
nonisolated enum CoverDesignRenderer {
    private static let yellow = UIColor(red: 1, green: 214 / 255, blue: 10 / 255, alpha: 1)
    private static let red = UIColor(red: 1, green: 69 / 255, blue: 58 / 255, alpha: 1)

    /// What is drawn over the picture, in order: the effect's shade, the layout's marks, the words,
    /// the person (cut out), the elements.
    static func draw(
        cover: VideoCover, design: CoverDesign, size: CGSize, cutout: Cutout?, in context: CGContext
    ) {
        drawShade(design.effect, size: size, in: context)
        if design.layout == .beforeAfter { drawSplit(size: size) }
        if design.layout.showsTitle || design.layout == .number {
            drawWords(title: cover.title, cover: cover, design: design, size: size, in: context)
        }
        if let cutout {
            if let outline = cutout.outline { outline.draw(in: CGRect(origin: .zero, size: size)) }
            cutout.person.draw(in: CGRect(origin: .zero, size: size))
        }
        drawElements(design, size: size, in: context)
    }

    /// The person cut out of the cover's picture, and (for "Outline me") the white silhouette behind it.
    struct Cutout {
        let person: UIImage
        let outline: UIImage?
    }

    // MARK: - The picture's effect

    private static func drawShade(_ effect: CoverEffect, size: CGSize, in context: CGContext) {
        let rect = CGRect(origin: .zero, size: size)
        if effect == .dim {
            UIColor.black.withAlphaComponent(0.38).setFill()
            context.fill(rect)
            return
        }
        // A soft shade at the top and the bottom keeps the words and the handle readable.
        let colors = [
            UIColor.black.withAlphaComponent(0.12).cgColor, UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.4).cgColor,
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.4, 0.6, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    /// The picture blurred, for "Blur back" (drawn instead of the sharp one).
    static func blurred(_ picture: UIImage, width: CGFloat) -> UIImage {
        guard let input = CIImage(image: picture), let filter = CIFilter(name: "CIGaussianBlur") else { return picture }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(width * 0.018, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let cg = CIContext().createCGImage(output, from: input.extent) else { return picture }
        return UIImage(cgImage: cg, scale: picture.scale, orientation: .up)
    }

    // MARK: - Before / After

    private static func drawSplit(size: CGSize) {
        UIColor.white.setFill()
        UIRectFill(CGRect(x: size.width / 2 - size.width * 0.007, y: 0, width: size.width * 0.014, height: size.height))
        label("BEFORE", at: CGPoint(x: size.width * 0.04, y: size.height * 0.36), background: .white, size: size, alignRight: false)
        label("AFTER", at: CGPoint(x: size.width * 0.96, y: size.height * 0.36), background: yellow, size: size, alignRight: true)
    }

    private static func label(_ text: String, at point: CGPoint, background: UIColor, size: CGSize, alignRight: Bool) {
        let font = words(.anton, size: size.width * 0.07)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let measured = (text as NSString).size(withAttributes: attributes)
        let padX = size.width * 0.03, padY = size.height * 0.005
        let box = CGRect(
            x: alignRight ? point.x - measured.width - padX * 2 : point.x, y: point.y,
            width: measured.width + padX * 2, height: measured.height + padY * 2
        )
        background.setFill()
        UIBezierPath(roundedRect: box, cornerRadius: size.width * 0.02).fill()
        (text as NSString).draw(at: CGPoint(x: box.minX + padX, y: box.minY + padY), withAttributes: attributes)
    }

    // MARK: - The words

    /// The words' typeface at `size`.
    static func words(_ font: CoverFont, size: CGFloat) -> UIFont {
        switch font {
        case .anton: UIFont(name: "Anton-Regular", size: size) ?? .systemFont(ofSize: size, weight: .heavy)
        case .grotesk: TextFont.font(.spaceGrotesk, weight: .bold, size: size, text: "A")
        case .serif: TextFont.font(.dmSerif, weight: .regular, size: size, text: "A")
        case .system: .systemFont(ofSize: size, weight: .heavy)
        }
    }

    private static func drawWords(title: String, cover: VideoCover, design: CoverDesign, size: CGSize, in context: CGContext) {
        let parts = design.words(of: title)
        let layout = design.layout
        let width = size.width
        let highlight = design.highlight(in: parts.words.count)
        // titleY moves the whole block: 0.2 is where it starts.
        var y = layout.textTop * size.height + CGFloat(cover.titleY - 0.2) * size.height
        let maxLine = width * 0.88
        let center = width / 2

        if layout == .kicker {
            let font = UIFont.monospacedSystemFont(ofSize: width * 0.044, weight: .heavy)
            let text = design.kicker(firstWord: parts.words.first?.uppercased()).uppercased()
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .kern: width * 0.004]
            let measured = (text as NSString).size(withAttributes: attributes)
            let pad = CGSize(width: width * 0.03, height: size.height * 0.006)
            let box = CGRect(x: center - measured.width / 2 - pad.width, y: y, width: measured.width + pad.width * 2, height: measured.height + pad.height * 2)
            UIColor.black.withAlphaComponent(0.6).setFill()
            UIBezierPath(roundedRect: box, cornerRadius: width * 0.015).fill()
            (text as NSString).draw(at: CGPoint(x: box.minX + pad.width, y: box.minY + pad.height), withAttributes: attributes)
            y = box.maxY + size.height * 0.012
        }
        if layout == .number, let number = parts.number {
            let font = words(design.font, size: width * 0.40)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: yellow, .shadow: shadow(width, blur: 0.05, offset: 0.01)]
            let measured = (number as NSString).size(withAttributes: attributes)
            (number as NSString).draw(at: CGPoint(x: center - measured.width / 2, y: y - measured.height * 0.08), withAttributes: attributes)
            y += measured.height * 0.85 + size.height * 0.012
        }
        guard !parts.words.isEmpty else { return }

        // Lay the words out in lines that fit, then draw each line centered.
        let font = words(design.font, size: width * layout.wordSize)
        let padX = width * 0.02, gapX = width * 0.024, gapY = size.height * 0.014, padY = size.height * 0.003
        let upper = parts.words.map { $0.uppercased() }
        let boxes = upper.map { word -> CGSize in
            let measured = (word as NSString).size(withAttributes: [.font: font])
            return CGSize(width: measured.width + padX * 2, height: measured.height * 1.05 + padY * 2)
        }
        var lines: [[Int]] = [[]]
        var lineWidth: CGFloat = 0
        for index in boxes.indices {
            let next = lineWidth + (lines[lines.count - 1].isEmpty ? 0 : gapX) + boxes[index].width
            if next > maxLine, !lines[lines.count - 1].isEmpty {
                lines.append([index])
                lineWidth = boxes[index].width
            } else {
                lines[lines.count - 1].append(index)
                lineWidth = next
            }
        }
        let lineHeights = lines.map { line in line.map { boxes[$0].height }.max() ?? 0 }
        let blockHeight = lineHeights.reduce(0, +) + gapY * CGFloat(max(0, lines.count - 1))
        if layout == .question {
            let widest = lines.map { line in line.reduce(CGFloat(0)) { $0 + boxes[$1].width } + gapX * CGFloat(max(0, line.count - 1)) }.max() ?? 0
            let box = CGRect(
                x: center - widest / 2 - width * 0.04, y: y - size.height * 0.02,
                width: widest + width * 0.08, height: blockHeight + size.height * 0.04
            )
            UIColor.black.withAlphaComponent(0.62).setFill()
            UIBezierPath(roundedRect: box, cornerRadius: width * 0.03).fill()
        }
        for (row, line) in lines.enumerated() {
            let total = line.reduce(CGFloat(0)) { $0 + boxes[$1].width } + gapX * CGFloat(max(0, line.count - 1))
            var x = center - total / 2
            for index in line {
                let box = CGRect(origin: CGPoint(x: x, y: y), size: boxes[index])
                let isHighlight = index == highlight
                if isHighlight {
                    yellow.setFill()
                    UIBezierPath(roundedRect: box, cornerRadius: width * 0.02).fill()
                }
                var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: isHighlight ? UIColor.black : UIColor.white]
                if !isHighlight, layout != .question { attributes[.shadow] = shadow(width, blur: 0.04, offset: 0.01) }
                (upper[index] as NSString).draw(at: CGPoint(x: box.minX + padX, y: box.minY + padY), withAttributes: attributes)
                x += box.width + gapX
            }
            y += lineHeights[row] + gapY
        }
    }

    private static func shadow(_ width: CGFloat, blur: CGFloat, offset: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = width * blur
        shadow.shadowOffset = CGSize(width: 0, height: width * offset)
        return shadow
    }

    // MARK: - Elements

    private static func drawElements(_ design: CoverDesign, size: CGSize, in context: CGContext) {
        let width = size.width, height = size.height
        if design.elements.contains(.arrow) { drawArrow(size: size, in: context) }
        if design.elements.contains(.circle) {
            context.saveGState()
            context.translateBy(x: width * (0.46 + 0.20), y: height * (0.55 + 0.10))
            context.rotate(by: -8 * .pi / 180)
            red.setStroke()
            let ring = UIBezierPath(ovalIn: CGRect(x: -width * 0.20, y: -height * 0.10, width: width * 0.40, height: height * 0.20))
            ring.lineWidth = width * 0.016
            ring.stroke()
            context.restoreGState()
        }
        if design.elements.contains(.series) {
            tag(
                Tag(text: design.episodeLabel, origin: CGPoint(x: width * 0.04, y: height * 0.03), fill: yellow, ink: .black,
                    font: .monospacedSystemFont(ofSize: width * 0.046, weight: .heavy), radius: width * 0.02, alignRight: false),
                in: size
            )
        }
        if design.elements.contains(.badge) {
            tag(
                Tag(text: "NEW", origin: CGPoint(x: width * 0.96, y: height * 0.03), fill: red, ink: .white,
                    font: .systemFont(ofSize: width * 0.048, weight: .heavy), radius: width * 0.05, alignRight: true),
                in: size
            )
        }
        if design.elements.contains(.handle), !design.handle.isEmpty {
            let text = design.handle.hasPrefix("@") ? design.handle : "@" + design.handle
            let attributes: [NSAttributedString.Key: Any] = [
                .font: TextFont.font(.spaceGrotesk, weight: .bold, size: width * 0.05, text: text),
                .foregroundColor: UIColor.white, .shadow: shadow(width, blur: 0.012, offset: 0.003),
            ]
            let measured = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: CGPoint(x: (width - measured.width) / 2, y: height * 0.77 - measured.height), withAttributes: attributes)
        }
    }

    /// A small rounded tag (the series tag, the badge): its text, where it sits and how it looks.
    private struct Tag {
        let text: String
        let origin: CGPoint
        let fill: UIColor
        let ink: UIColor
        let font: UIFont
        let radius: CGFloat
        let alignRight: Bool
    }

    private static func tag(_ tag: Tag, in size: CGSize) {
        let attributes: [NSAttributedString.Key: Any] = [.font: tag.font, .foregroundColor: tag.ink]
        let measured = (tag.text as NSString).size(withAttributes: attributes)
        let pad = CGSize(width: size.width * 0.032, height: size.height * 0.006)
        let box = CGRect(
            x: tag.alignRight ? tag.origin.x - measured.width - pad.width * 2 : tag.origin.x, y: tag.origin.y,
            width: measured.width + pad.width * 2, height: measured.height + pad.height * 2
        )
        tag.fill.setFill()
        UIBezierPath(roundedRect: box, cornerRadius: tag.radius).fill()
        (tag.text as NSString).draw(at: CGPoint(x: box.minX + pad.width, y: box.minY + pad.height), withAttributes: attributes)
    }

    /// The yellow hand-drawn arrow, curving down and to the right.
    private static func drawArrow(size: CGSize, in context: CGContext) {
        let frame = CGRect(x: size.width * 0.08, y: size.height * 0.58, width: size.width * 0.30, height: size.width * 0.26)
        let scaleX = frame.width / 70, scaleY = frame.height / 60
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: frame.minX + x * scaleX, y: frame.minY + y * scaleY) }
        let path = UIBezierPath()
        path.move(to: point(6, 8))
        path.addCurve(to: point(56, 48), controlPoint1: point(24, 10), controlPoint2: point(46, 22))
        path.move(to: point(56, 48))
        path.addLine(to: point(58, 32))
        path.move(to: point(56, 48))
        path.addLine(to: point(41, 42))
        path.lineWidth = 5 * scaleX
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.5).cgColor)
        yellow.setStroke()
        path.stroke()
        context.restoreGState()
    }

    // MARK: - The person

    /// The person in `picture` (already the size of the cover) cut out, with a white silhouette for
    /// "Outline me". Nil when no person is found.
    static func cutout(of picture: UIImage, outlined: Bool) -> Cutout? {
        guard let input = CIImage(image: picture), let mask = PersonMasker.mask(for: input) else { return nil }
        let context = CIContext()
        func image(_ output: CIImage) -> UIImage? {
            context.createCGImage(output, from: input.extent).map { UIImage(cgImage: $0, scale: 1, orientation: .up) }
        }
        let clear = CIImage(color: .clear).cropped(to: input.extent)
        guard let person = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: input, kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: mask,
        ])?.outputImage, let personImage = image(person) else { return nil }
        guard outlined else { return Cutout(person: personImage, outline: nil) }
        let grown = mask.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: max(2, picture.size.width * 0.006)])
        let white = CIImage(color: .white).cropped(to: input.extent)
        let outline = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: white, kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: grown,
        ])?.outputImage.flatMap(image)
        return Cutout(person: personImage, outline: outline)
    }
}
