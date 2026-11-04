import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// "YOU" under the map's core (`UniverseMap`): its label on the plate it sits on, laid over the universe's night, with and without Increase
    /// Contrast.
    @Test func youReadsOnItsPlate() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let night = universeRGB(Palette.bg, traits, over: nil)
            let plate = universeRGB(Palette.Universe.youPlate, traits, over: night)
            let value = ColorContrast.ratio(universeRGB(Palette.inkSoft, traits, over: plate), plate)
            #expect(value >= ColorContrast.textMinimum, "YOU on its plate, contrast \(contrast.rawValue): \(value)")
        }
    }

    private func universeRGB(_ color: Color, _ traits: UITraitCollection, over background: ColorContrast.RGB?) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let solid = ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return ColorContrast.composite(solid, alpha: Double(alpha), over: background ?? ColorContrast.RGB(red: 0, green: 0, blue: 0))
    }
}
