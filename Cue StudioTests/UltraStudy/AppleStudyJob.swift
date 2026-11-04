//
//  AppleStudyJob.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One script Apple Intelligence writes for the Ultra study on an iPhone (`AppleStudyDeviceTests`): the case, the route, the improvements on
/// and the window of seconds it aims at.
nonisolated struct AppleStudyJob: Codable, Sendable, CustomTestStringConvertible {
    let id: String
    let item: UltraStudyJob.Case
    /// An `AIModelRoute` raw value: "onDevice" or "privateCloud".
    let route: String
    /// "formatDefinitions" (`definesFormats`) and "ideaKind" (`followsIdeaKind`).
    let variants: [String]
    /// The arm's name in the reports, e.g. "D0" (the device as it is) or "D1" (with the improvements).
    let config: String
    /// The seconds Apple Intelligence aims at on Auto inside the network's range (`AppleScriptLength.window`); nil keeps the app's.
    let window: [Double]?

    var testDescription: String { id }

    private enum CodingKeys: String, CodingKey {
        case id, item = "case", route, variants, config, window
    }
}
