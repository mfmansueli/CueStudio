//
//  ExportResult.swift
//  Cue Studio
//

import Foundation

/// An exported file, with what it was drawn without: words whose family wasn't there come out in the system's face, and the
/// creator is told (`fontFallback`).
nonisolated struct ExportResult: Equatable, Sendable {
    let url: URL
    /// Script families the words needed that weren't on this iPhone when the frames were drawn (`FontPackNeeds`).
    var unavailableFonts: Set<FontPackNeed> = []
    /// Imported families the words named that aren't on this iPhone (`TakeEdit.customFontUses`).
    var missingCustomFamilies: Set<String> = []

    /// Why some words are in the system's face, nil when none are. A family still downloading comes first: it is the one exporting
    /// again fixes.
    var fontFallback: ExportFontFallback? {
        if !unavailableFonts.isEmpty { return .notDownloaded }
        return missingCustomFamilies.isEmpty ? nil : .notOnThisIPhone
    }
}
