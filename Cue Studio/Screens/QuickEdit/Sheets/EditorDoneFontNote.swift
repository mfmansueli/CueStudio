//
//  EditorDoneFontNote.swift
//  Cue Studio
//

import Foundation

/// The line on "Is it ready to post?" when some words would come out in the system's face (`QuickEditViewModel.fontsNotReady`),
/// with what fixes it, before the creator picks where the video goes.
nonisolated enum EditorDoneFontNote {
    static func text(for fallback: ExportFontFallback) -> String {
        switch fallback {
        case .notDownloaded: String(localized: "A font is still downloading · stay online to export it")
        case .notOnThisIPhone: String(localized: "A font you imported isn’t on this iPhone · import it again or pick another")
        }
    }
}
