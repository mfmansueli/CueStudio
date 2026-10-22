//
//  WatchPalette.swift
//  Cue Studio Watch
//

import SwiftUI

/// The watch's colors (v31 board): the night sky behind, red for recording, yellow for the text, green for a working link,
/// orange for what needs a look on the iPhone. Every text color is at least 4.5:1 on `night`.
enum WatchPalette {
    /// The sky at the top of the screen and the night under it.
    static let sky = Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3C / 255)
    static let night = Color(red: 0x05 / 255, green: 0x06 / 255, blue: 0x0D / 255)
    static let ink = Color.white
    /// Secondary text (8.4:1 on `night`, 6.9:1 on `sky`).
    static let inkSoft = Color(red: 0xA3 / 255, green: 0xA6 / 255, blue: 0xBD / 255)
    /// Text that must read on `surface` too (9.8:1).
    static let inkMuted = Color(red: 0xCD / 255, green: 0xD0 / 255, blue: 0xE0 / 255)
    /// Secondary buttons.
    static let surface = Color(red: 0x22 / 255, green: 0x25 / 255, blue: 0x3A / 255)
    /// The stroke of the speed control.
    static let line = Color(red: 0x3B / 255, green: 0x3E / 255, blue: 0x5E / 255)
    /// Record (white on it: 5.4:1).
    static let record = Color(red: 0xD1 / 255, green: 0x1A / 255, blue: 0x2A / 255)
    /// End's tinted ground and its outline.
    static let stopGround = Color(red: 0x2A / 255, green: 0x14 / 255, blue: 0x18 / 255)
    static let stopLine = Color(red: 0xFF / 255, green: 0x69 / 255, blue: 0x61 / 255)
    /// "Recording" and "The camera keeps recording."
    static let recordText = Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x84 / 255)
    /// The text's controls and the countdown.
    static let reading = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x0A / 255)
    /// Dark marks on `reading`.
    static let onReading = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
    static let linked = Color(red: 0x6E / 255, green: 0xE5 / 255, blue: 0x96 / 255)
    static let saved = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let onSaved = Color(red: 0x06 / 255, green: 0x2A / 255, blue: 0x12 / 255)
    static let warning = Color(red: 0xFF / 255, green: 0xB3 / 255, blue: 0x40 / 255)
    /// Voice Following.
    static let voice = Color(red: 0x64 / 255, green: 0xD2 / 255, blue: 0xFF / 255)
    /// The page dot not shown.
    static let dotOff = Color(red: 0x4A / 255, green: 0x4D / 255, blue: 0x6A / 255)

    static var background: some View {
        RadialGradient(colors: [sky, night], center: UnitPoint(x: 0.25, y: 0), startRadius: 0, endRadius: 240)
            .ignoresSafeArea()
    }
}
