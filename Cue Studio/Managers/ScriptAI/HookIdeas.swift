//
//  HookIdeas.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// Fresh opening lines for "Pick a new hook": five, of which the sheet shows the three said within the hook’s seconds (`ScriptTextEditing.hookOptions`).
/// Measured on the iPhone (ScriptToolsQualityDeviceTests, 01/11/2026), asked for three of at most eight words, the device wrote 7 to 15 and Private
/// Cloud Compute 6 to 15: one in three would have been one the hook tip calls long.
@Generable
nonisolated struct HookIdeas {
    @Guide(description: "Five different opening lines, each one short sentence that can be said in about three seconds.", .count(5))
    var hooks: [String]
}
