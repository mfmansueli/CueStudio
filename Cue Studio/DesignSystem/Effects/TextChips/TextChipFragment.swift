//
//  TextChipFragment.swift
//  Cue Studio
//

import UIKit

/// A paragraph of a TextKit 2 text view that has chips in it (`TextChipLayoutDelegate` hands it out): each run marked with a
/// `TextChipBox` gets its rounded chip and symbol drawn behind its glyphs, then the paragraph draws as usual. The characters stay where
/// they are, so the caret, the selection and editing don't know the chip is there.
nonisolated final class TextChipFragment: NSTextLayoutFragment {
    /// A chip is a little taller than the words in it and the symbol sits in the first character's kern: room around the paragraph so
    /// neither is clipped.
    override var renderingSurfaceBounds: CGRect {
        super.renderingSurfaceBounds.insetBy(dx: -2, dy: -6)
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        for line in textLineFragments {
            drawChips(of: line, at: point, in: context)
        }
        super.draw(at: point, in: context)
    }

    /// The part of each chip that falls on `line` (a chip only spans two lines when it is wider than the page).
    private func drawChips(of line: NSTextLineFragment, at point: CGPoint, in context: CGContext) {
        let range = line.characterRange
        guard range.length > 0 else { return }
        let origin = CGPoint(x: point.x + line.typographicBounds.minX, y: point.y + line.typographicBounds.minY)
        let baseline = origin.y + line.glyphOrigin.y
        line.attributedString.enumerateAttribute(TextChipAttribute.nsKey, in: range) { value, run, _ in
            guard let box = value as? TextChipBox else { return }
            let startX = line.locationForCharacter(at: run.location).x
            let endX = NSMaxRange(run) < NSMaxRange(range)
                ? line.locationForCharacter(at: NSMaxRange(run)).x
                : line.typographicBounds.width
            let rect = box.metrics.chipRect(from: origin.x + startX, to: origin.x + endX, baseline: baseline)
            draw(box, in: rect, context: context, withSymbol: run.location == firstCharacter(of: box, in: line.attributedString, from: run))
        }
    }

    /// Where the chip's run starts in the whole paragraph: the symbol only goes on the line where the chip begins.
    private func firstCharacter(of box: TextChipBox, in string: NSAttributedString, from run: NSRange) -> Int {
        var start = run.location
        while start > 0, string.attribute(TextChipAttribute.nsKey, at: start - 1, effectiveRange: nil) as? TextChipBox === box {
            start -= 1
        }
        return start
    }

    private func draw(_ box: TextChipBox, in rect: CGRect, context: CGContext, withSymbol: Bool) {
        let metrics = box.metrics
        let path = UIBezierPath(roundedRect: rect, cornerRadius: metrics.cornerRadius)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        box.fill.setFill()
        path.fill()
        let rim = UIBezierPath(
            roundedRect: rect.insetBy(dx: TextChipMetrics.rimWidth / 2, dy: TextChipMetrics.rimWidth / 2),
            cornerRadius: metrics.cornerRadius - TextChipMetrics.rimWidth / 2
        )
        rim.lineWidth = TextChipMetrics.rimWidth
        box.rim.setStroke()
        rim.stroke()
        guard withSymbol, let name = box.chip.symbol else { return }
        guard let image = UIImage(systemName: name, withConfiguration: metrics.symbolConfiguration)?
            .withTintColor(box.ink, renderingMode: .alwaysOriginal) else { return }
        let centre = metrics.symbolCentre(name, in: rect)
        image.draw(at: CGPoint(x: centre.x - image.size.width / 2, y: centre.y - image.size.height / 2))
    }
}
