//
//  Palette+Remote.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Settings › Remote: the two devices of its scene (`RemoteHero`), the link between them and the pairing code.
    enum Remote {
        /// A device's glass, its rim and the island at its top.
        static let deviceBody = Color(hex: 0x0A0B16)
        static let deviceRim = Color(hex: 0x3B3E5E)
        static let deviceIsland = Color.black
        /// The lines of the script on the teleprompter's screen.
        static let screenText = Color.white
        /// The link while nothing is connected: dots drifting toward the teleprompter.
        static let linkIdle = Color(hex: 0x6E7196)
        /// The link once a remote is connected, and the light that runs along it, a command at a time.
        static let linkLive = Color(hex: 0x5FE08A)
        static let pulse = Color(hex: 0xE4FFEC)
        /// The glow under the scene: the prompter's yellow until a remote connects, then green.
        static let glowIdle = Palette.acc
        static let glowLive = Palette.success
        /// The paper the QR code is printed on, and the ✓ on its green badge.
        static let qrPaper = Color.white
        static let checkInk = Color(hex: 0x062A12)
        /// Each letter of the pairing code on its own tile.
        static let codeTile = Palette.surface
        static let codeTileRim = Color(hex: 0x34375A)
    }
}
