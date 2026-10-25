//
//  BrandColorsEnvironment.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// The colors of the brand kit the video wears (`AppliedBrandKit`): first in every color picker of the editor.
    @Entry var brandColors: [OverlayColor] = []
}
