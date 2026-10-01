//
//  QuickEditExit.swift
//  Cue Studio
//

import Foundation

/// How the editor was left.
enum QuickEditExit {
    /// Done: the edit was saved on the take.
    case done
    /// Export: the edit was saved and the take should be shared.
    case export
}
