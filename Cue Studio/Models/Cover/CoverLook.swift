//
//  CoverLook.swift
//  Cue Studio
//

import Foundation

/// The part of a cover design that is a style: kept by "Save as my style" and given to new covers.
nonisolated struct CoverLook: Codable, Hashable, Sendable {
    var layout: CoverLayout
    var font: CoverFont
    var effect: CoverEffect
    var series: Bool
}
