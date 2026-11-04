import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// My Cue Voice's fuel tank (`Palette.Fuel`): the fuel, at its yellow top and its amber bottom, against the empty tank it fills (3:1, it is
    /// the meter's value), with and without Increase Contrast.
    @Test func theFuelStandsOutInItsTank() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let tank = solid(Palette.Fuel.tank, traits)
            for (name, fuel) in [("fuel", Palette.Fuel.fuel), ("fuelDeep", Palette.Fuel.fuelDeep)] {
                let value = ColorContrast.ratio(solid(fuel, traits), tank)
                #expect(value >= ColorContrast.componentMinimum, "\(name) in the tank, contrast \(contrast.rawValue): \(value)")
            }
        }
    }

    private func solid(_ color: Color, _ traits: UITraitCollection) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: nil)
        return ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
    }
}
