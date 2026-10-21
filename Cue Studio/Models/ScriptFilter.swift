//
//  ScriptFilter.swift
//  Cue Studio
//

import Foundation

/// The chip row on the Scripts screen: everything, one destination, or one folder.
nonisolated enum ScriptFilter: Hashable, Sendable {
    case all
    case platform(Platform)
    case folder(String)

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .platform(let platform): platform.label
        case .folder(let name): name
        }
    }

    func matches(_ script: Script) -> Bool {
        switch self {
        case .all: true
        case .platform(let platform): script.platform == platform
        case .folder(let name): script.folder == name
        }
    }

    /// One chip per primary platform, plus any other platform a script already uses (Stories).
    static func platformFilters(for scripts: [Script]) -> [ScriptFilter] {
        let used = Set(scripts.map(\.platform))
        return Platform.allCases
            .filter { Platform.primary.contains($0) || used.contains($0) }
            .map(ScriptFilter.platform)
    }

    /// Scripts matching the filter whose title or text contains `query`, in their original order.
    static func apply(_ filter: ScriptFilter, query: String, to scripts: [Script]) -> [Script] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return scripts.filter { script in
            guard filter.matches(script) else { return false }
            guard !needle.isEmpty else { return true }
            let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            return script.title.range(of: needle, options: options) != nil
                || script.text.range(of: needle, options: options) != nil
        }
    }
}
