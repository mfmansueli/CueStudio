//
//  FreeExportLabels.swift
//  Cue Studio
//

import Foundation

/// The words that count the free exports, in the three places that do (09, "Free exports running out"): the plan card on Profile (9.1), the
/// meter on Share (8.1) and the line under Share on the take (6.3). `left` is nil on Pro or its trial. The tone says how to colour it:
/// quiet, yellow for the last one, orange once they are gone.
nonisolated enum FreeExportLabels {
    enum Tone: Equatable, Sendable { case quiet, last, exhausted }

    struct Label: Equatable, Sendable {
        let text: String
        let tone: Tone
    }

    private static var limit: Int { UsagePolicy.freeExports }

    /// 9.1: "4 OF 5 EXPORTS LEFT", "LAST FREE EXPORT", "0 OF 5 EXPORTS LEFT", "PRO · UNLIMITED".
    static func plan(left: Int?) -> Label {
        guard let left else { return Label(text: String(localized: "PRO · UNLIMITED"), tone: .quiet) }
        if left == 1 { return Label(text: String(localized: "LAST FREE EXPORT"), tone: .last) }
        return Label(text: String(localized: "\(left) OF \(limit) EXPORTS LEFT"), tone: left == 0 ? .exhausted : .quiet)
    }

    /// 8.1: "4 OF 5 LEFT", "LAST FREE EXPORT", "0 OF 5 LEFT · EXPORT WITH PRO", "PRO · UNLIMITED EXPORTS".
    static func meter(left: Int?) -> Label {
        guard let left else { return Label(text: String(localized: "PRO · UNLIMITED EXPORTS"), tone: .quiet) }
        if left == 1 { return Label(text: String(localized: "LAST FREE EXPORT"), tone: .last) }
        if left == 0 { return Label(text: String(localized: "\(left) OF \(limit) LEFT · EXPORT WITH PRO"), tone: .exhausted) }
        return Label(text: String(localized: "\(left) OF \(limit) LEFT"), tone: .quiet)
    }

    /// 6.3, before "· GO PRO": "4 OF 5 FREE EXPORTS LEFT", "LAST FREE EXPORT", "0 OF 5 FREE EXPORTS LEFT" and, once the creator said "Not now" to the
    /// sheet, "READY · EXPORT WITH PRO"; "PRO · UNLIMITED EXPORTS" on Pro, where Go Pro is not shown.
    static func take(left: Int?, declined: Bool) -> Label {
        guard let left else { return Label(text: String(localized: "PRO · UNLIMITED EXPORTS"), tone: .quiet) }
        if left == 1 { return Label(text: String(localized: "LAST FREE EXPORT"), tone: .last) }
        if left == 0 {
            let text = declined ? String(localized: "READY · EXPORT WITH PRO") : String(localized: "\(left) OF \(limit) FREE EXPORTS LEFT")
            return Label(text: text, tone: .exhausted)
        }
        return Label(text: String(localized: "\(left) OF \(limit) FREE EXPORTS LEFT"), tone: .quiet)
    }
}
