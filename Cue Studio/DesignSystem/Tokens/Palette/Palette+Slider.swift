//
//  Palette+Slider.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// `CueSlider`: a 4 pt track, a 4 pt yellow fill and a 24 pt white thumb (`Metrics.slider*`).
    enum Slider {
        /// `#6E7496` at 35%.
        static let track = Color(hex: 0x6E7496, opacity: 0.35)
        static let fill = Palette.acc
        static let thumb = Color.white
        static let thumbShadow = Color.black.opacity(0.4)
    }
}
