//
//  Palette+Toast.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Toasts (`ToastView`), and the editor's work pill and notices that wear their pill (`toastSurface(in:)`): opaque, one step
    /// above the screen, with a light rim that sets it apart from the app's night and a shadow that sets it apart from a bright
    /// video. Measured in `PaletteContrastTests.theToastReadsOverAnyScreen`.
    enum Toast {
        /// The pill (as `surface3`): white words at 13:1, the yellow button at 9:1.
        static let fill = Color(hex: 0x2B2F48)
        /// Its rim: 3:1 or more against the app's ground, so the pill never melts into a dark screen.
        static let rim = Color(normal: Color.white.opacity(0.24), increasedContrast: Color.white.opacity(0.4))
        /// Its shadow: a wide one that lifts it off a bright picture, and a close one under its edge.
        static let shadow = Color.black.opacity(0.5)
        static let shadowNear = Color.black.opacity(0.35)

        /// The round icon of each kind (`ToastKind`), with a black glyph: green ✓, yellow ★, orange !.
        static let done = Color(hex: 0x34C759)
        static let cue = Color(hex: 0xFFD60A)
        static let problem = Color(hex: 0xFF9F0A)
        static let glyph = Color.black

        /// The working ring: its track, and the arc that turns.
        static let ringTrack = Color.white.opacity(0.28)
        static let ring = Color(hex: 0xFFD60A)
    }
}
