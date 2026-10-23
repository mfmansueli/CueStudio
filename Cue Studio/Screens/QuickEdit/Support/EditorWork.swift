//
//  EditorWork.swift
//  Cue Studio
//

import Foundation

/// Work the creator waits for with the editor open, said over the preview with how far it is and Cancel (`EditorWorkPill`): a
/// clip being reversed, a photo or video coming from the library (from iCloud first when it isn't on the iPhone).
nonisolated struct EditorWork: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case reversing, importing
    }

    let kind: Kind
    /// The job Cancel stops (`EditorJobs`).
    let job: EditorJobs.Kind
    /// 0 to 1; nil until the first report.
    var fraction: Double?

    /// "Reversing · 40%".
    var label: String {
        let percent = fraction.map { Int(($0 * 100).rounded()) }
        switch (kind, percent) {
        case (.reversing, let percent?): return String(localized: "Reversing · \(percent)%")
        case (.reversing, nil): return String(localized: "Reversing…")
        case (.importing, let percent?): return String(localized: "Importing · \(percent)%")
        case (.importing, nil): return String(localized: "Importing…")
        }
    }
}
