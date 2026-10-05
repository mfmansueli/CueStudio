//
//  FormatChoice.swift
//  Cue Studio
//

import Foundation

/// A choice on the format sheet (v30 · F, 09 §1): Auto (Cue picks from the idea), Talking head (the plain "you, the camera, one
/// clear point" video, which has no `ScriptType` of its own) or a `ScriptType`. Nine are tiles in the grid; the formats the grid
/// doesn't show (Hot take / reply, Announcement, Apology) are rows under "More formats", so no format is lost. "Start from a format"
/// has no Auto.
nonisolated enum FormatChoice: Hashable, Identifiable, Sendable {
    case auto
    case talkingHead
    case type(ScriptType)

    var id: String {
        switch self {
        case .auto: "auto"
        case .talkingHead: "talking"
        case .type(let type): type.rawValue
        }
    }

    /// The grid's nine tiles, in order: Auto, Talking head, Tutorial, Storytime, List / tips, Review, Myth vs fact, POV, Sponsored ad.
    static let gridTiles: [FormatChoice] = [
        .auto, .talkingHead, .type(.tutorial), .type(.story), .type(.list), .type(.review),
        .type(.mythFact), .type(.pov), .type(.ad),
    ]

    /// "More formats": one row for every `ScriptType` the grid doesn't show, in the enum's order (Hot take / reply, Launch, Apology).
    static let moreFormats: [FormatChoice] = ScriptType.allCases
        .filter { type in !gridTiles.contains(.type(type)) }
        .map(FormatChoice.type)

    /// Every choice the sheet has: the grid, then "More formats".
    static let allTiles: [FormatChoice] = gridTiles + moreFormats

    /// What goes on the script: nil for Auto and Talking head.
    var scriptType: ScriptType? {
        if case .type(let type) = self { type } else { nil }
    }

    init(_ type: ScriptType?) {
        self = type.map(FormatChoice.type) ?? .auto
    }

    var title: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .talkingHead: String(localized: "Talking head")
        case .type(let type): type.structure.label
        }
    }

    var summary: String {
        switch self {
        case .auto: String(localized: "Cue picks from your idea")
        case .talkingHead: String(localized: "You, the camera, one clear point")
        case .type(let type): type.summary
        }
    }

    /// The sections a script of this format has, in order.
    var sections: [String] {
        switch self {
        case .auto: ScriptStructure.generic.blocks
        case .talkingHead: [String(localized: "Hook"), String(localized: "Point"), String(localized: "Why it matters"), String(localized: "CTA")]
        case .type(let type): type.structure.blocks
        }
    }

    var isSerious: Bool {
        if case .type(let type) = self { type.structure.isSerious } else { false }
    }

    /// A sponsored ad needs its brand brief first.
    var needsBrandBrief: Bool { self == .type(.ad) }
}
