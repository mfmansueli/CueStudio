import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    @Test func primaryButtonInkStaysReadableAtThePeakOfItsShine() throws {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let ink = try renderedShinePeak(Palette.accInk, traits: traits)
            let fill = try renderedShinePeak(Palette.acc, traits: traits)
            var normalRed: CGFloat = 0
            UIColor(Palette.accInk).resolvedColor(with: traits).getRed(&normalRed, green: nil, blue: nil, alpha: nil)
            #expect(ink.red > Double(normalRed) + 0.1, "The sample must contain the bright band")
            let value = ColorContrast.ratio(ink, fill)
            #expect(value >= ColorContrast.textMinimum, "Ink under the brightest shine, contrast \(contrast.rawValue): \(value)")
        }
    }

    /// Off screen the ambient clock stands at zero. This interval puts the actual sweep at its midpoint on that first frame.
    private func renderedShinePeak(_ color: Color, traits: UITraitCollection) throws -> ColorContrast.RGB {
        let interval = ShineSweep<Capsule>.firstSweep + CueMotion.Duration.shineSweep / 2
        let sample = Color(uiColor: UIColor(color).resolvedColor(with: traits))
            .frame(width: 200, height: 54)
            .shineSweep(interval: interval)
        let renderer = ImageRenderer(content: sample)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let pixels = try RenderParity.pixels(image, size: CGSize(width: 200, height: 54))
        let offset = (27 * 200 + 100) * 4
        return ColorContrast.RGB(
            red: Double(pixels[offset]) / 255, green: Double(pixels[offset + 1]) / 255, blue: Double(pixels[offset + 2]) / 255
        )
    }
}
