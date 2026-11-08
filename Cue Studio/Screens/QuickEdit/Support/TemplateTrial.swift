//
//  TemplateTrial.swift
//  Cue Studio
//

import Foundation

/// A template being tried on (owner, 08/11/2026): it is on the video while its sheet says what it changed and what it kept, so
/// the preview shows how it really looks with the creator's kit; Apply keeps it as one undo step, Cancel takes it off without one.
struct TemplateTrial: Equatable {
    /// One thing the template changes, or keeps, as the sheet says it.
    struct Line: Equatable, Identifiable {
        let id: String
        let systemImage: String
        let title: String
        let detail: String
    }

    let template: VideoTemplate
    /// What the creator styled by hand before it went on (stays unless `replacing` says so).
    let manual: ManualStyleChanges
    var replacing = ReplacedManualChanges()
    /// What it changes, in order: captions, texts, an opening text.
    var lines: [Line]
}
