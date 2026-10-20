//
//  ScriptCueSymbol.swift
//  Cue Studio
//

import Foundation

/// The SF Symbol a cue's chip shows before its name on the page: a known cue gets its own (pause ⏸, look at camera 👁, demo ☝︎…),
/// a cue of the creator's own none. A cue is known by its name in any of the app's languages, not only the interface's: a script
/// written in Portuguese keeps "[pausa]" when the interface is in English, and the AI sometimes drops an accent ("olhe para a camera").
nonisolated enum ScriptCueSymbol {
    static func name(for cue: ScriptCue) -> String {
        switch cue {
        case .pause: "pause.fill"
        case .beat: "metronome"
        case .smile: "face.smiling"
        case .lookAtCamera: "eye"
        case .confident: "bolt.fill"
        case .slowDown: "tortoise"
        case .breathe: "wind"
        case .showProduct: "shippingbox"
        case .demo: "hand.point.up"
        case .emphasis: "exclamationmark"
        }
    }

    /// The symbol for a cue's name (what is between its brackets), or nil for a cue Cue doesn't know.
    static func name(forCue name: String) -> String? {
        known[folded(name)].map { Self.name(for: $0) }
    }

    /// Every cue's name in every language the app has, folded, to the cue. Built once.
    private static let known: [String: ScriptCue] = {
        var names: [String: ScriptCue] = [:]
        let bundles = Bundle.main.localizations.compactMap { language in
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        for cue in ScriptCue.allCases {
            names[folded(key(of: cue))] = cue
            for bundle in bundles {
                names[folded(bundle.localizedString(forKey: key(of: cue), value: nil, table: nil))] = cue
            }
        }
        return names
    }()

    /// The cue's key in the String Catalog (its English name), as `ScriptCue.name` looks it up.
    private static func key(of cue: ScriptCue) -> String {
        switch cue {
        case .pause: "pause"
        case .beat: "beat"
        case .smile: "smile"
        case .lookAtCamera: "look at camera"
        case .confident: "confident"
        case .slowDown: "slow down"
        case .breathe: "breathe"
        case .showProduct: "show product"
        case .demo: "demo"
        case .emphasis: "emphasis"
        }
    }

    private static func folded(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
