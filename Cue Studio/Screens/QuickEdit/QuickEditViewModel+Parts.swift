//
//  QuickEditViewModel+Parts.swift
//  Cue Studio
//

import Foundation

/// The part of a video picked to replace something (`MediaPartSheet`): it goes where it was asked for, or, closed, the copy
/// made for it goes.
extension QuickEditViewModel {
    func confirmPart(_ choice: MediaPartChoice) {
        session.partChoice = nil
        switch choice.purpose {
        case .replaceMedia(let id): overlays.replaceMedia(id, with: choice.pick)
        case .replaceClip(let id): clips.replaceClip(id, with: choice.pick.imported, from: choice.pick.start)
        }
    }

    func cancelPart(_ choice: MediaPartChoice) {
        session.partChoice = nil
        session.importedFiles.remove(choice.pick.imported.fileName)
        EditMediaFiles.remove([choice.pick.imported.fileName])
    }
}
