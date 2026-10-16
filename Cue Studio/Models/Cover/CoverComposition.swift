//
//  CoverComposition.swift
//  Cue Studio
//

import Foundation

/// A cover made in Cover Studio: the template it started from, how its picture is framed, how its title is set, the graphics
/// on it (in drawing order), what is done to the picture (and how strongly), and for a before/after the second picture.
/// Optional on `VideoCover`: covers made before it keep their v26 design (`CoverDesign`) or their plain title until they're
/// opened in Cover Studio (`CoverComposition(legacy:)`).
nonisolated struct CoverComposition: Codable, Hashable, Sendable {
    var template: CoverTemplate
    var framing = CoverFraming()
    var title = CoverTitleStyle()
    var items: [CoverItem] = []
    var effect: CoverEffect = .clean
    /// How strong Dim or Blur is, 0 to 1.
    var effectAmount = 0.5
    /// The before/after's second half; nil for every other cover.
    var split: CoverSplit?

    init(template: CoverTemplate) {
        self.template = template
    }

    /// The item with `id`.
    func item(_ id: UUID) -> CoverItem? {
        items.first { $0.id == id }
    }
}
