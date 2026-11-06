//
//  QuickEditViewModel+FontCheck.swift
//  Cue Studio
//

import Foundation

extension QuickEditViewModel {
    /// Before the video goes out (the editor's "Is it ready to post?"): words whose font isn't drawn now would come out in the
    /// system's face. An imported family that isn't on this iPhone first (exporting can't bring it back), then a script's family
    /// still on its way (the export asks for it and waits a little, `VideoExportService.fontWait`). Nil when every word has its font.
    var fontsNotReady: ExportFontFallback? {
        if edit.customFontUses.contains(where: { !CustomFontRegistry.shared.has($0.family) }) { return .notOnThisIPhone }
        let needs = FontPackNeeds.needs(in: edit, han: FontPackRegistry.shared.hanReading)
        return brand.fontPacks.unavailable(needs).isEmpty ? nil : .notDownloaded
    }
}
