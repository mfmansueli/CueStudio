//
//  OverlayRenderer.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// Draws captions and the "Made with Cue" badge as images, sized to the output frame, so the
/// compositor only has to place them.
nonisolated enum OverlayRenderer {
    /// One overlay per caption, at the chosen position, visible while its words are said.
    static func captions(_ cues: [CaptionCue], style: CaptionStyle, position: CaptionPosition, frame: CGSize) -> [FrameOverlay] {
        let unit = frame.width / 402
        return cues.compactMap { cue in
            guard let image = captionImage(cue.text, style: style, unit: unit, maxWidth: frame.width * 0.8) else { return nil }
            let size = image.extent.size
            let centerY = frame.height * (1 - position.verticalFraction)
            let origin = CGPoint(x: ((frame.width - size.width) / 2).rounded(), y: (centerY - size.height / 2).rounded())
            return FrameOverlay(image: image, origin: origin, span: TimeSpan(start: cue.start, end: cue.end))
        }
    }

    /// The free plan's badge at the bottom right, for the whole video.
    static func watermark(frame: CGSize) -> FrameOverlay? {
        let unit = frame.width / 402
        let font = UIFont.systemFont(ofSize: 12 * unit, weight: .bold)
        let text = String(localized: "Made with Cue") as NSString
        let textWidth = text.size(withAttributes: [.font: font]).width
        let size = CGSize(width: (textWidth + 34 * unit).rounded(), height: (26 * unit).rounded())
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.withAlphaComponent(0.45).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8 * unit).fill()
            UIColor(red: 1, green: 0.84, blue: 0.04, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 10 * unit, y: (size.height - 3 * unit) / 2, width: 12 * unit, height: 3 * unit), cornerRadius: 1.5 * unit).fill()
            text.draw(at: CGPoint(x: 28 * unit, y: (size.height - font.lineHeight) / 2), withAttributes: [
                .font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            ])
        }
        guard let ciImage = CIImage(image: image) else { return nil }
        let margin = 18 * unit
        return FrameOverlay(image: ciImage, origin: CGPoint(x: frame.width - size.width - margin, y: margin * 2), span: nil)
    }

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return format
    }

    private static func captionImage(_ text: String, style: CaptionStyle, unit: CGFloat, maxWidth: CGFloat) -> CIImage? {
        let string = style == .bold ? text.uppercased() : text
        let font: UIFont
        let foreground: UIColor
        var background: UIColor?
        switch style {
        case .classic:
            font = .systemFont(ofSize: 15 * unit, weight: .semibold)
            foreground = .white
            background = UIColor.black.withAlphaComponent(0.62)
        case .bold:
            font = .systemFont(ofSize: 19 * unit, weight: .heavy)
            foreground = .white
        case .highlight:
            font = .systemFont(ofSize: 16 * unit, weight: .bold)
            foreground = .black
            background = UIColor(red: 1, green: 0.84, blue: 0.04, alpha: 1)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(style == .bold ? 0.7 : 0)
        shadow.shadowBlurRadius = 6 * unit
        shadow.shadowOffset = CGSize(width: 0, height: 2 * unit)
        let attributed = NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: foreground, .paragraphStyle: paragraph, .shadow: shadow,
        ])
        let padding = CGSize(width: 10 * unit, height: 4 * unit)
        let bounds = attributed.boundingRect(with: CGSize(width: maxWidth - padding.width * 2, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
        let size = CGSize(width: ceil(bounds.width + padding.width * 2), height: ceil(bounds.height + padding.height * 2))
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            if let background {
                background.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8 * unit).fill()
            }
            attributed.draw(with: CGRect(x: padding.width, y: padding.height, width: bounds.width, height: bounds.height), options: [.usesLineFragmentOrigin], context: nil)
        }
        return CIImage(image: image)
    }
}
