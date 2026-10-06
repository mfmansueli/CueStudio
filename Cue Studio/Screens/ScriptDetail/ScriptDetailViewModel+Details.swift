//
//  ScriptDetailViewModel+Details.swift
//  Cue Studio
//

import Foundation

/// Script details: the script's type and the blocks the sheet lists.
extension ScriptDetailViewModel {
    /// "Script type": the sections and the AI suggestions follow it.
    func setType(_ type: ScriptType?) {
        library.update(scriptID) { $0.type = type }
        sheet = nil
        let blocks = (type?.structure ?? .generic).blocks.joined(separator: " · ")
        toast.show(String(localized: "Sections: \(blocks)"))
    }

    /// A block of the Details sheet: the sheet closes and the page scrolls to it.
    func showBlock(_ summary: BlockSummary) {
        sheet = nil
        readScrollTarget = summary.firstParagraph
    }
}
