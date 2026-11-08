//
//  CaptionLineChoice.swift
//  Cue Studio
//

import Foundation

/// Place or Zoom asked from a caption line picked on the main timeline (`CaptionsViewModel+LineChoice`).
struct CaptionLineChoice: Identifiable, Equatable {
    enum Kind: Equatable {
        case place, zoom
    }

    let lineID: UUID
    let kind: Kind

    var id: String { "\(lineID)-\(kind)" }
}
