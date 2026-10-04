//
//  FontCredit.swift
//  Cue Studio
//

import Foundation

/// A font bundled with Cue and its license, for Settings › Acknowledgements. Every one is under the
/// SIL Open Font License 1.1, which allows embedding it in an app; its text ships in the bundle.
nonisolated struct FontCredit: Identifiable, Hashable, Sendable {
    let name: String
    /// What it's used for in Cue.
    let use: String
    let copyright: String
    /// The license's text file in the bundle (without ".txt").
    let licenseFile: String

    var id: String { name }

    /// The license text, as shipped.
    var licenseText: String {
        Bundle.main.url(forResource: licenseFile, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    static let all: [FontCredit] = [
        FontCredit(
            name: "DM Sans", use: String(localized: "Texts and captions on the video"),
            copyright: "Copyright 2014 The DM Sans Project Authors", licenseFile: "dmsans-OFL"
        ),
        FontCredit(
            name: "DM Serif Display", use: String(localized: "Texts and captions on the video"),
            copyright: "Copyright 2014-2018 Adobe, Copyright 2019 Google LLC", licenseFile: "dmserifdisplay-OFL"
        ),
        FontCredit(
            name: "Space Grotesk", use: String(localized: "Texts and captions on the video"),
            copyright: "Copyright 2020 The Space Grotesk Project Authors", licenseFile: "spacegrotesk-OFL"
        ),
        FontCredit(
            name: "Anton", use: String(localized: "Captions on the video"),
            copyright: "Copyright 2020 The Anton Project Authors", licenseFile: "anton-OFL"
        ),
        FontCredit(
            name: "Inter", use: String(localized: "Captions on the video"),
            copyright: "Copyright 2020 The Inter Project Authors", licenseFile: "inter-OFL"
        ),
        FontCredit(
            name: "Poppins", use: String(localized: "Captions on the video"),
            copyright: "Copyright 2020 The Poppins Project Authors", licenseFile: "poppins-OFL"
        ),
        FontCredit(
            name: "Manrope", use: String(localized: "Captions on the video"),
            copyright: "Copyright 2018 The Manrope Project Authors", licenseFile: "manrope-OFL"
        ),
        FontCredit(
            name: "Unbounded", use: String(localized: "Texts on the video"),
            copyright: "Copyright 2022 The Unbounded Project Authors", licenseFile: "unbounded-OFL"
        ),
        FontCredit(
            name: "Instrument Serif", use: String(localized: "Texts on the video"),
            copyright: "Copyright 2022 The Instrument Serif Project Authors", licenseFile: "instrumentserif-OFL"
        ),
        FontCredit(
            name: "Space Mono", use: String(localized: "Texts on the video"),
            copyright: "Copyright 2016 The Space Mono Project Authors", licenseFile: "spacemono-OFL"
        ),
        FontCredit(
            name: "Syne", use: String(localized: "Texts on the video"),
            copyright: "Copyright 2017 The Syne Project Authors", licenseFile: "syne-OFL"
        ),
        FontCredit(
            name: "Caveat", use: String(localized: "Texts on the video"),
            copyright: "Copyright 2014 The Caveat Project Authors", licenseFile: "caveat-OFL"
        ),
        FontCredit(
            name: "Lexend · Atkinson Hyperlegible · Source Serif 4", use: String(localized: "The teleprompter's text"),
            copyright: "The Lexend Project Authors · Braille Institute of America · The Source Serif 4 Project Authors",
            licenseFile: "FONTS_LICENSE"
        ),
    ]
}
