//
//  TipChoice.swift
//  Cue Studio
//

import Foundation

/// An answer a tip takes with one tap (`TipCard`'s row of options): "Feminine", "Formal".
nonisolated struct TipChoice: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
}
