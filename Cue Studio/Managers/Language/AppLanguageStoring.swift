//
//  AppLanguageStoring.swift
//  Cue Studio
//

import Foundation

/// Where Cue's interface language is kept. The real store is the system's per-app language list,
/// so tests and UI tests use one in memory and never change the simulator's.
protocol AppLanguageStoring: AnyObject {
    /// The `.lproj` the creator picked for Cue ("pt-BR", "zh-Hans"), or nil to follow the iPhone.
    var chosenLocalization: String? { get set }
    /// The `.lproj` the iPhone's languages pick among Cue's, used while nothing is chosen.
    var systemLocalization: String { get }
    /// The iPhone's own languages, most preferred first, whatever Cue's interface is in. Voice
    /// Following reads regional variants from them (en-GB over en-US), never the interface language.
    var systemLanguages: [String] { get }
}
