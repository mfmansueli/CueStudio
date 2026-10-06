//
//  UniverseSharedFile.swift
//  Cue Studio
//

import Foundation

/// The card's file, ready for the system share sheet (the item of `.sheet(item:)`).
struct UniverseSharedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}
