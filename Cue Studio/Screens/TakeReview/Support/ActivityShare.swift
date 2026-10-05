//
//  ActivityShare.swift
//  Cue Studio
//

import Foundation

/// A video going to the system share sheet: the exported file, which operation it belongs to, and the destination whose
/// tile was tapped (nil for "More"). The sheet's result is told apart by `id`, so a callback heard twice acts once.
struct ActivityShare: Identifiable, Equatable {
    let id = UUID()
    let operationID: UUID
    let url: URL
    let destination: ShareDestination?
}
